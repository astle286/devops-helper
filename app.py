from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename
import yaml
import os
import json
import redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import hcl2

app = Flask(__name__)
SNIPPET_DIR = "snippets"

# Counters for HTTP status codes
http_requests_total = Counter(
    'http_requests_total', 'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

# Histogram for request latency
http_request_latency_seconds = Histogram(
    'http_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'endpoint'],
    buckets=(0.1, 0.3, 0.5, 1, 2, 5)
)


r = redis.Redis(host="redis", port=6379, decode_responses=True)

def load_snippet_with_lang(filename):
    path = os.path.join(SNIPPET_DIR, filename)
    try:
        with open(path, "r") as f:
            content = f.read()
    except FileNotFoundError:
        return "Snippet not found.", "language-none", "Plain Text"

    # Map extensions to Prism language classes + labels
    ext = os.path.splitext(filename)[1].lower()
    lang_map = {
        ".yml": ("language-yaml", "YAML"),
        ".yaml": ("language-yaml", "YAML"),
        ".ini": ("language-ini", "INI"),
        ".sh": ("language-bash", "Bash"),
        ".txt": ("language-docker", "Dockerfile"),
        ".json": ("language-json", "JSON"),
        ".md": ("language-markdown", "Markdown"),
        ".cfg": ("language-none", "Plain Text"),
        ".conf": ("language-none", "Plain Text"),
        ".tf": ("language-hcl", "Terraform HCL"),
    }
    lang, label = lang_map.get(ext, ("language-none", "Plain Text"))
    return content, lang, label



@app.route("/")
def index():
    cards = []
    for fname in os.listdir(SNIPPET_DIR):
        title = fname.replace("_", " ").replace(".txt", "").title()
        content, lang, label = load_snippet_with_lang(fname)
        cards.append({
            "title": title,
            "filename": fname,
            "lang": lang,
            "label": label
        })
    return render_template("index.html", snippets=cards)

@app.route("/dockerfile")
def dockerfile():
    content, lang, label = load_snippet_with_lang("dockerfile.txt")
    snippets = [{"content": content, "lang": lang, "label": label}]
    return render_template("dockerfile.html", snippets=snippets, page_title="Dockerfile Snippets")


@app.route("/docker-compose")
def docker_compose():
    content, lang, label = load_snippet_with_lang("docker-compose.yml")
    snippets = [{"content": content, "lang": lang, "label": label}]
    return render_template("docker-compose.html", snippets=snippets, page_title="Docker Compose Templates")



@app.route("/kubernetes")
def kubernetes():
    files = ["k8s-deployment.yml", "k8s-service.yml", "k8s-pod.yml"]
    snippets = [dict(zip(["content", "lang", "label"], load_snippet_with_lang(f))) for f in files]
    return render_template("kubernetes.html", snippets=snippets, page_title="Kubernetes Manifests")



@app.route("/ansible")
def ansible():
    files = ["ansible-inventory.ini", "ansible-playbook.yml"]
    snippets = [dict(zip(["content", "lang", "label"], load_snippet_with_lang(f))) for f in files]
    return render_template("ansible.html", snippets=snippets, page_title="Ansible Templates")



@app.route("/linux")
def linux_scripts():
    content, lang, label = load_snippet_with_lang("linux-scripts.sh")
    snippets = [{"content": content, "lang": lang, "label": label}]
    return render_template("linux.html", snippets=snippets, page_title="Linux Scripts")



@app.route("/cron")
def cron_jobs():
    content, lang, label = load_snippet_with_lang("cron-examples.txt")
    snippets = [{"content": content, "lang": lang, "label": label}]
    return render_template("cron.html", snippets=snippets, page_title="Cron Job Examples")



@app.route("/yaml-formatter", methods=["GET"])
def yaml_formatter():
    # just renders the page
    return render_template("yaml_formatter.html")


def detect_mode(raw_input: str):
    try:
        json.loads(raw_input)
        return "json"
    except Exception:
        try:
            yaml.safe_load(raw_input)
            return "yaml"
        except Exception:
            return None

@app.route("/api/format", methods=["POST"])
def api_format():
    raw_input = request.form.get("input", "")
    mode = detect_mode(raw_input)
    cache_key = f"format:{mode}:{raw_input}"
    cached = r.get(cache_key)
    if cached:
        return jsonify({"output": cached, "mode": mode})

    try:
        parsed = yaml.safe_load(raw_input) if mode == "yaml" else json.loads(raw_input)
        formatted = yaml.safe_dump(parsed, sort_keys=False) if mode == "yaml" else json.dumps(parsed, indent=2)
        r.setex(cache_key, 120, formatted)
        return jsonify({"output": formatted, "mode": mode})
    except Exception as e:
        return jsonify({"error": str(e)})

@app.route("/api/parse", methods=["POST"])
def api_parse():
    raw_input = request.form.get("input", "")
    mode = detect_mode(raw_input)
    cache_key = f"parse:{mode}:{raw_input}"
    cached = r.get(cache_key)
    if cached:
        return jsonify({"output": cached, "mode": mode})

    try:
        parsed = yaml.safe_load(raw_input) if mode == "yaml" else json.loads(raw_input)
        result = str(parsed)
        r.setex(cache_key, 120, result)
        return jsonify({"output": result, "mode": mode})
    except Exception as e:
        return jsonify({"error": str(e)})

@app.route("/api/convert", methods=["POST"])
def api_convert():
    raw_input = request.form.get("input", "")
    mode = detect_mode(raw_input)
    cache_key = f"convert:{mode}:{raw_input}"
    cached = r.get(cache_key)
    if cached:
        return jsonify({"output": cached, "mode": mode})

    try:
        parsed = yaml.safe_load(raw_input) if mode == "yaml" else json.loads(raw_input)
        if mode == "yaml":
            converted = json.dumps(parsed, indent=2)
            new_mode = "json"
        else:
            converted = yaml.safe_dump(parsed, sort_keys=False)
            new_mode = "yaml"
        r.setex(cache_key, 120, converted)
        return jsonify({"output": converted, "mode": new_mode})
    except Exception as e:
        return jsonify({"error": str(e)})


@app.route("/upload-snippet", methods=["GET", "POST"])
def upload_snippet():
    message = None
    if request.method == "POST":
        # Get title and content from form
        title = request.form.get("snippetTitle")
        content = request.form.get("snippetText")

        # Sanitize filename from title
        filename = secure_filename(f"{title.replace(' ', '_').lower()}.txt")
        path = os.path.join(SNIPPET_DIR, filename)

        # Save snippet to file
        with open(path, "w") as f:
            f.write(content)

        message = f"Snippet '{title}' uploaded successfully!"
    return render_template("upload_snippet.html", message=message)

@app.route("/view/<filename>")
def view_snippet(filename):
    content, lang, label = load_snippet_with_lang(filename)
    snippet = {"content": content, "lang": lang, "label": label, "title": filename}
    return render_template("snippet_view.html", snippet=snippet)


@app.route("/search", methods=["GET", "POST"])
def search():
    import json
    results = []
    query = None

    if request.method == "POST":
        query = request.form["query"].lower()
    else:
        query = request.args.get("q")
        if query:
            query = query.lower()

    if query:
        # Check cache first
        cached = r.get(f"search:{query}")
        if cached:
            results = json.loads(cached)
        else:
            for fname in os.listdir(SNIPPET_DIR):
                content, lang, label = load_snippet_with_lang(fname)
                if query in content.lower() or query in label.lower():
                    results.append({"content": content, "lang": lang, "label": label})
            # Cache results for 60 seconds
            r.setex(f"search:{query}", 60, json.dumps(results))

    return render_template("search.html", results=results, query=query)


@app.errorhandler(404)
def page_not_found(e):
    return render_template("404.html"), 404

@app.errorhandler(500)
def internal_error(e):
    return render_template("500.html"), 500

@app.before_request
def start_timer():
    request.start_time = time.time()

@app.after_request
def record_metrics(response):
    if not request.path.startswith(('/static', '/favicon.ico')):
        latency = time.time() - request.start_time
        http_request_latency_seconds.labels(request.method, request.path).observe(latency)
        http_requests_total.labels(request.method, request.path, response.status_code).inc()
    return response

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000,debug=True)
