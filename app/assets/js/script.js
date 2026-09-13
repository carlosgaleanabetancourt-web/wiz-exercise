const taskInput = document.querySelector(".task-input input"),
filters = document.querySelectorAll(".filters span"),
clearAll = document.querySelector(".clear-btn"),
taskBox = document.querySelector(".task-box"),
editBadge = document.querySelector(".edit-badge"),
toastEl = document.getElementById("toast");
let editId, isEditTask, editStatus = false;
let pendingDeleteId = null;
let deleteTimer = null;
let clearAllTimer = null;
var userid = changeUsername();
fetchTodos().then(data => showTodo("all", data, true));
allTodos = "";

filters.forEach(btn => {
    btn.addEventListener("click", () => {
        document.querySelector("span.active").classList.remove("active");
        btn.classList.add("active");
        showTodo(btn.id, "", false);
    });
});

function changeUsername() {
    let userid = getCookie("userID");
    let username = getCookie("username");
    document.getElementById("username").innerText = username;
    return userid;
}

function getCookie(name) {
    var cookieArr = document.cookie.split(";");
    for (var i = 0; i < cookieArr.length; i++) {
        var cookiePair = cookieArr[i].split("=");
        if (name == cookiePair[0].trim()) {
            return decodeURIComponent(cookiePair[1]);
        }
    }
    return null;
}

function showToast(message, isError) {
    toastEl.textContent = message;
    toastEl.className = "toast show" + (isError ? " error" : "");
    setTimeout(() => { toastEl.className = "toast"; }, 3000);
}

function escapeAttr(str) {
    return String(str).replace(/&/g,'&amp;').replace(/'/g,'&#39;').replace(/"/g,'&quot;');
}

function unescapeAttr(str) {
    var el = document.createElement('textarea');
    el.innerHTML = str;
    return el.value;
}

function showTodo(filter, todos = "", changeAllTodos) {
    if (changeAllTodos) {
        allTodos = todos;
    }
    let liTag = "";
    if (allTodos) {
        allTodos.forEach((todo) => {
            let completed = todo.status == "completed" ? "checked" : "";
            if (filter == todo.status || filter == "all") {
                let isConfirming = pendingDeleteId === todo["ID"];
                liTag += `<li class="task${isConfirming ? ' confirm-delete' : ''}">
                            <label for="${todo["ID"]}">
                                <input onclick="updateStatus(this)" type="checkbox" id="${todo["ID"]}" ${completed}>
                                <p class="${completed}">${escapeAttr(todo.name)}</p>
                            </label>
                            <div class="task-actions">
                                <i class="uil uil-pen" onclick='editTask("${todo["ID"]}","${escapeAttr(todo["name"])}","${todo["status"]}")'></i>
                                <i class="uil uil-trash${isConfirming ? ' confirm-icon' : ''}" onclick='deleteTask("${todo["ID"]}", "${filter}")'></i>
                            </div>
                        </li>`;
            }
        });
    }
    taskBox.innerHTML = liTag || `<span>You don't have any task here</span>`;
    let checkTask = taskBox.querySelectorAll(".task");
    !checkTask.length ? clearAll.classList.remove("active") : clearAll.classList.add("active");
    taskBox.offsetHeight >= 300 ? taskBox.classList.add("overflow") : taskBox.classList.remove("overflow");
}

function updateStatus(selectedTask) {
    let taskName = selectedTask.parentElement.lastElementChild;
    let newStatus = "";
    if (selectedTask.checked) {
        taskName.classList.add("checked");
        newStatus = "completed";
    } else {
        taskName.classList.remove("checked");
        newStatus = "pending";
    }
    findAndEditTodo(selectedTask.id, taskName.innerText, newStatus);
    updateTodo(selectedTask.id, taskName.innerText, newStatus).then(data => console.log(data));
}

function editTask(taskId, textName, taskStatus) {
    editId = taskId;
    editStatus = taskStatus;
    isEditTask = true;
    taskInput.value = unescapeAttr(textName);
    taskInput.focus();
    taskInput.classList.add("active", "editing");
    taskInput.placeholder = "Editing task... (Esc to cancel)";
    if (editBadge) editBadge.classList.add("visible");
}

function cancelEdit() {
    isEditTask = false;
    editId = null;
    taskInput.value = "";
    taskInput.classList.remove("editing");
    taskInput.placeholder = "Add a new task";
    if (editBadge) editBadge.classList.remove("visible");
}

function deleteTask(deleteId, filter) {
    if (pendingDeleteId === deleteId) {
        clearTimeout(deleteTimer);
        pendingDeleteId = null;
        deleteTimer = null;
        isEditTask = false;
        findAndDeleteTodo(deleteId);
        deleteTodos(deleteId).then(data => {
            showTodo(filter, "", false);
            console.log(data);
        });
    } else {
        if (deleteTimer) {
            clearTimeout(deleteTimer);
            pendingDeleteId = null;
        }
        pendingDeleteId = deleteId;
        showTodo(filter, "", false);
        deleteTimer = setTimeout(() => {
            pendingDeleteId = null;
            deleteTimer = null;
            showTodo(filter, "", false);
        }, 3000);
    }
}

clearAll.addEventListener("click", () => {
    if (clearAllTimer) {
        clearTimeout(clearAllTimer);
        clearAllTimer = null;
        clearAll.textContent = "Clear All";
        clearAll.classList.remove("confirming");
        isEditTask = false;
        allTodos.splice(0, allTodos.length);
        ClearAllTodos().then(data => console.log(data));
        showTodo("all", "", false);
    } else {
        clearAll.textContent = "Confirm?";
        clearAll.classList.add("confirming");
        clearAllTimer = setTimeout(() => {
            clearAllTimer = null;
            clearAll.textContent = "Clear All";
            clearAll.classList.remove("confirming");
        }, 3000);
    }
});

taskInput.addEventListener("keyup", e => {
    if (e.key == "Escape" && isEditTask) {
        cancelEdit();
        return;
    }
    let userTask = taskInput.value.trim();
    if (e.key == "Enter" && userTask) {
        if (!isEditTask) {
            allTodos = !allTodos ? [] : allTodos;
            let taskInfo = {name: userTask, status: "pending"};
            addTodo(taskInfo).then(data => {
                if (!data["error"]) {
                    taskInfo["ID"] = data["insertedId"];
                    allTodos.push(taskInfo);
                    showTodo(document.querySelector("span.active").id, "", false);
                    console.log(data);
                }
            });
        } else {
            updateTodo(editId, userTask, editStatus).then(data => console.log(data));
            findAndEditTodo(editId, userTask, editStatus);
            showTodo(document.querySelector("span.active").id, "", false);
            cancelEdit();
        }
        taskInput.value = "";
    }
});

function findAndDeleteTodo(id) {
    allTodos.forEach((todo, index) => {
        if (todo.ID == id) {
            allTodos.splice(index, 1);
        }
    });
}

function findAndEditTodo(id, name, status) {
    allTodos.forEach((todo) => {
        if (todo.ID == id) {
            todo.name = name;
            todo.status = status;
        }
    });
}

function handleError(response, data) {
    if (response.status != 200) {
        showToast(data.error || JSON.stringify(data), true);
    }
}

async function ClearAllTodos() {
    const response = await fetch('/todos/' + userid, {
        method: 'DELETE',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }
    });
    const data = await response.json();
    handleError(response, data);
    return data;
}

async function updateTodo(id, name, status) {
    const response = await fetch('/todo', {
        method: 'PUT',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            'ID': id,
            'name': name,
            'user_id': userid,
            'status': status
        })
    });
    const data = await response.json();
    handleError(response, data);
    return data;
}

async function addTodo(todo) {
    const response = await fetch('/todo/' + userid, {
        method: 'POST',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            'name': todo["name"],
            'status': todo["status"]
        })
    });
    const data = await response.json();
    handleError(response, data);
    return data;
}

async function fetchTodos() {
    const response = await fetch('/todos/' + userid);
    const data = await response.json();
    handleError(response, data);
    return data;
}

async function deleteTodos(id) {
    const response = await fetch('/todo/' + userid + '/' + id, {
        method: 'DELETE'
    });
    const data = await response.json();
    handleError(response, data);
    return data;
}
