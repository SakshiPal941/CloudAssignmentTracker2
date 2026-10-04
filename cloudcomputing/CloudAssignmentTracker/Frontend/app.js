console.log("APP.JS LOADED");

let items = [];

const LABEL = { PENDING: "Pending", IN_PROGRESS: "In progress", COMPLETED: "Done" };
let tab = "all", editingId = null, confirmId = null;

const $ = (s) => document.querySelector(s);
const list = $("#list"), form = $("#form");

/* --- API layer: talks to Spring Boot via Nginx's /api/ proxy --- */
async function apiGet() {
  const res = await fetch("/api/assignments");
  if (!res.ok) throw new Error("GET failed: " + res.status);
  return res.json();
}
async function apiCreate(payload) {
  const res = await fetch("/api/assignments", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  if (!res.ok) throw new Error("POST failed: " + res.status);
  return res.json();
}
async function apiUpdate(id, payload) {
  const res = await fetch("/api/assignments/" + id, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  if (!res.ok) throw new Error("PUT failed: " + res.status);
  return res.json();
}
async function apiDelete(id) {
  const res = await fetch("/api/assignments/" + id, { method: "DELETE" });
  if (!res.ok && res.status !== 204) throw new Error("DELETE failed: " + res.status);
}

async function apiSubscribeToNotifications(email) {
  const res = await fetch("/api/notifications/subscribe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email })
  });

  const data = await res.json();

  if (!res.ok) {
    throw new Error(data.message || "Subscription failed");
  }

  return data;
}

async function loadAssignments() {
  try {
    items = await apiGet();
    console.log("RECEIVED:", items);
    render();
  } catch (err) {
    console.error("FETCH FAILED:", err);
    list.innerHTML = '<div class="empty">Could not load assignments right now. The server may still be starting up, so please try again in a few minutes.</div>';
  }
}

function overdue(it) {
  if (it.status === "COMPLETED" || !it.dueDate) return false;
  const today = new Date(); today.setHours(0, 0, 0, 0);
  return new Date(it.dueDate + "T00:00:00") < today;
}
function fmtDue(iso, done) {
  if (!iso) return "\u2014";
  const d = new Date(iso + "T00:00:00");
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const days = Math.round((d - today) / 86400000);
  const short = d.toLocaleDateString("en-NZ", { day: "numeric", month: "short" });
  if (done) return short;
  if (days === 0) return "today";
  if (days === 1) return "tomorrow";
  if (days < 0) return short + " \u00b7 late";
  return short;
}

function render() {
  const counts = {
    all: items.length,
    open: items.filter((i) => i.status !== "COMPLETED").length,
    done: items.filter((i) => i.status === "COMPLETED").length
  };
  $("#count").textContent = counts.open + " open \u00b7 " + counts.done + " done";

  $("#tabs").innerHTML =
    [["all", "All " + counts.all], ["open", "Open " + counts.open], ["done", "Done " + counts.done]]
      .map(([k, l]) => '<button class="tab' + (tab === k ? " active" : "") + '" data-tab="' + k + '">' + l + "</button>")
      .join("") +
    '<button class="tab new' + (tab === "form" ? " active" : "") + '" data-tab="form">' + (editingId ? "Editing" : "+ New") + "</button>";

  const showForm = tab === "form";
  form.hidden = !showForm;
  list.hidden = showForm;
  if (showForm) return;

  const visible = items
    .filter((it) => tab === "all" || (tab === "open" ? it.status !== "COMPLETED" : it.status === "COMPLETED"))
    .sort((a, b) => (a.status === "COMPLETED") - (b.status === "COMPLETED") || String(a.dueDate).localeCompare(String(b.dueDate)));

  list.innerHTML = visible.length
    ? visible.map((it, i) => {
        const done = it.status === "COMPLETED";
        return (
          '<div class="row' + (done ? " is-done" : "") + '" style="animation-delay:' + Math.min(i, 8) * 45 + 'ms">' +
            '<button class="dot' + (done ? " done" : "") + '" data-toggle="' + it.id + '" title="Toggle done"><i></i></button>' +
            '<div class="cell">' +
              '<span class="title">' + esc(it.title) + "</span>" +
              '<div class="sub">' +
                '<span class="course">' + esc(it.description || "\u2014") + "</span>" +
                '<span class="due' + (overdue(it) ? " late" : "") + '">' + fmtDue(it.dueDate, done) + "</span>" +
                '<div class="tools">' +
                  '<button data-edit="' + it.id + '">Edit</button>' +
                  '<button class="del' + (confirmId === it.id ? " confirm" : "") + '" data-del="' + it.id + '">' + (confirmId === it.id ? "Sure?" : "Delete") + "</button>" +
                "</div>" +
              "</div>" +
            "</div>" +
            '<span class="pill ' + it.status.toLowerCase() + '">' + (LABEL[it.status] || it.status) + "</span>" +
          "</div>"
        );
      }).join("")
    : '<div class="empty">Nothing here.</div>';
}

function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }

function openForm(it) {
  tab = "form"; editingId = it ? it.id : null; confirmId = null;
  $("#f-title").value = it ? it.title : "";
  $("#f-description").value = it ? (it.description || "") : "";
  $("#f-due").value = it ? it.dueDate : "";
  $("#f-status").value = it ? it.status : "PENDING";
  $("#save").textContent = it ? "Save changes" : "Add assignment";
  render();
}

document.addEventListener("click", async (e) => {
  const t = e.target.closest("[data-tab],[data-toggle],[data-edit],[data-del]");
  if (!t) return;

  if (t.dataset.tab) {
    if (t.dataset.tab === "form") openForm(null);
    else { tab = t.dataset.tab; confirmId = null; render(); }
    return;
  }

  if (t.dataset.toggle) {
    const it = items.find((x) => x.id == t.dataset.toggle);
    const newStatus = it.status === "COMPLETED" ? "PENDING" : "COMPLETED";
    const payload = { title: it.title, description: it.description, dueDate: it.dueDate, status: newStatus };
    try {
      const updated = await apiUpdate(it.id, payload);
      it.status = updated.status;
      render();
    } catch (err) {
      console.error("Toggle failed:", err);
      alert("Could not update assignment status.");
    }
    return;
  }

  if (t.dataset.edit) {
    openForm(items.find((x) => x.id == t.dataset.edit));
    return;
  }

  if (t.dataset.del) {
    const id = Number(t.dataset.del);
    if (confirmId === id) {
      try {
        await apiDelete(id);
        items = items.filter((x) => x.id !== id);
        confirmId = null;
        render();
      } catch (err) {
        console.error("Delete failed:", err);
        alert("Could not delete assignment.");
      }
    } else {
      confirmId = id;
      render();
    }
  }
});

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const title = $("#f-title").value.trim();
  const dueDate = $("#f-due").value;
  if (!title || !dueDate) return;

  const payload = {
    title,
    description: $("#f-description").value.trim(),
    dueDate,
    status: $("#f-status").value
  };

  $("#save").disabled = true;
  try {
    if (editingId) {
      const updated = await apiUpdate(editingId, payload);
      items = items.map((x) => (x.id === editingId ? updated : x));
    } else {
      const created = await apiCreate(payload);
      items.push(created);
    }
    tab = "all"; editingId = null;
    render();
  } catch (err) {
    console.error("Save failed:", err);
    alert("Could not save assignment.");
  } finally {
    $("#save").disabled = false;
  }
});

$("#cancel").addEventListener("click", () => { tab = "all"; editingId = null; render(); });

loadAssignments();

const notificationForm = $("#notification-form");
const notificationEmail = $("#notification-email");
const notificationMessage = $("#notification-message");

if (notificationForm) {
  notificationForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const email = notificationEmail.value.trim();
    const button = notificationForm.querySelector("button");

    if (!email) return;

    button.disabled = true;
    button.textContent = "Subscribing...";
    notificationMessage.textContent = "";

    try {
      const data = await apiSubscribeToNotifications(email);

      notificationMessage.textContent = data.message;
      notificationEmail.value = "";
      notificationForm.style.display = "none";

    } catch (err) {
      console.error("Notification subscription failed:", err);
      notificationMessage.textContent =
        err.message || "Could not subscribe to notifications.";
    } finally {
      button.disabled = false;
      button.textContent = "Notify me";
    }
  });
}