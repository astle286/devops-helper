document.addEventListener("DOMContentLoaded", () => {
  const input = document.getElementById("yamlInput");
  const output = document.getElementById("formattedOutput");
  const modeBadge = document.getElementById("modeBadge");
  const copyBtn = document.getElementById("copyBtn");
  const downloadBtn = document.getElementById("downloadBtn");
  const clearBtn = document.getElementById("clearBtn");

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
  document.getElementById("formatBtn").addEventListener("click", () => callApi("/api/format"));
  document.getElementById("parseBtn").addEventListener("click", () => callApi("/api/parse"));
  document.getElementById("convertBtn").addEventListener("click", () => callApi("/api/convert"));

  // --- clear button ---
  if (clearBtn) {
    clearBtn.addEventListener("click", () => {
      input.value = "";
      output.textContent = "";
      modeBadge.textContent = "";
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
  downloadBtn.addEventListener("click", () => {
    const blob = new Blob([output.innerText], { type: "text/plain" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "output.txt";
    link.click();
    URL.revokeObjectURL(link.href);
  });

  // --- upload ---
  document.getElementById("uploadBtn").addEventListener("click", () => {
    document.getElementById("fileInput").click();
  });
  document.getElementById("fileInput").addEventListener("change", e => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => input.value = reader.result;
      reader.readAsText(file);
    }
  });
});
