document.addEventListener("DOMContentLoaded", () => {
  const input = document.getElementById("yamlInput");
  const output = document.getElementById("formattedOutput");
  const modeBadge = document.getElementById("modeBadge");
  const copyBtn = document.getElementById("copyBtn");
  const downloadBtn = document.getElementById("downloadBtn");
  const clearBtn = document.getElementById("clearBtn");

  // Upload snippet page elements
  const uploadBtn = document.getElementById("uploadBtn");
  const fileInput = document.getElementById("fileInput");
  const snippetText = document.getElementById("snippetText");

  // --- helper to call backend ---
  async function callApi(endpoint) {
    const formData = new FormData();
    formData.append("input", input.value);
    const res = await fetch(endpoint, { method: "POST", body: formData });
    const data = await res.json();
    if (data.output) {
      output.textContent = data.output;
      modeBadge.textContent = data.mode ? `Detected: ${data.mode.toUpperCase()}` : "";
    } else {
      output.textContent = "Error: " + data.error;
      modeBadge.textContent = "";
    }
  }

  // --- button wiring ---
  const formatBtn = document.getElementById("formatBtn");
  const parseBtn = document.getElementById("parseBtn");
  const convertBtn = document.getElementById("convertBtn");

  if (formatBtn) formatBtn.addEventListener("click", () => callApi("/api/format"));
  if (parseBtn) parseBtn.addEventListener("click", () => callApi("/api/parse"));
  if (convertBtn) convertBtn.addEventListener("click", () => callApi("/api/convert"));

  // --- clear button ---
  if (clearBtn) {
    clearBtn.addEventListener("click", () => {
      if (input) input.value = "";
      if (output) output.textContent = "";
      if (modeBadge) modeBadge.textContent = "";
    });
  }

  // --- copy with tooltip ---
  if (copyBtn && output) {
    copyBtn.style.position = "relative";
    copyBtn.addEventListener("click", () => {
      navigator.clipboard.writeText(output.innerText).then(() => {
        const tooltip = document.createElement("span");
        tooltip.className = "copy-tooltip";
        tooltip.innerText = "Copied!";
        copyBtn.appendChild(tooltip);
        setTimeout(() => {
          tooltip.classList.add("fade-out");
          setTimeout(() => tooltip.remove(), 500);
        }, 1000);
      }).catch(err => console.error("Copy failed:", err));
    });
  }

  // --- download ---
  if (downloadBtn) {
    downloadBtn.addEventListener("click", () => {
      const blob = new Blob([output.innerText], { type: "text/plain" });
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = "output.txt";
      link.click();
      URL.revokeObjectURL(link.href);
    });
  }

  // --- upload (for snippet page) ---
  if (uploadBtn && fileInput && snippetText) {
    uploadBtn.addEventListener("click", () => {
      fileInput.click();
    });

    fileInput.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = () => {
          snippetText.value = reader.result;
        };
        reader.readAsText(file);
      }
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
  const content = document.getElementById("content");

  // fade out before navigation
  document.querySelectorAll("nav a, .btn").forEach(link => {
    link.addEventListener("click", e => {
      // only apply if it's an internal link
      if (link.href && link.href.startsWith(window.location.origin)) {
        content.classList.remove("active");
        setTimeout(() => {
          window.location = link.href;
        }, 300); // match transition duration
        e.preventDefault();
      }
    });
  });

  // fade in on load
    setTimeout(() => content.classList.add("active"), 50);
  });

  document.querySelectorAll('.snippet').forEach(snippet => {
    snippet.addEventListener('click', () => {
      const content = snippet.querySelector('.snippet-content');
      content.classList.toggle('active');
    });
  });
});