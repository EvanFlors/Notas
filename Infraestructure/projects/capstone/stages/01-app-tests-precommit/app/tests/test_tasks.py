from __future__ import annotations

from fastapi.testclient import TestClient


def test_list_tasks_empty(client: TestClient) -> None:
    r = client.get("/tasks")
    assert r.status_code == 200
    assert r.json() == []


def test_create_task_minimal(client: TestClient) -> None:
    r = client.post("/tasks", json={"title": "write tests"})
    assert r.status_code == 201
    body = r.json()
    assert body["id"] >= 1
    assert body["title"] == "write tests"
    assert body["done"] is False
    assert "created_at" in body


def test_create_task_with_done_true(client: TestClient) -> None:
    r = client.post("/tasks", json={"title": "done one", "done": True})
    assert r.status_code == 201
    assert r.json()["done"] is True


def test_get_task_roundtrip(client: TestClient) -> None:
    created = client.post("/tasks", json={"title": "roundtrip"}).json()
    r = client.get(f"/tasks/{created['id']}")
    assert r.status_code == 200
    assert r.json()["title"] == "roundtrip"


def test_get_task_missing_returns_404(client: TestClient) -> None:
    r = client.get("/tasks/9999")
    assert r.status_code == 404
    assert r.json()["detail"] == "task not found"


def test_patch_task_title_and_done(client: TestClient) -> None:
    created = client.post("/tasks", json={"title": "old"}).json()
    r = client.patch(f"/tasks/{created['id']}", json={"title": "new", "done": True})
    assert r.status_code == 200
    body = r.json()
    assert body["title"] == "new"
    assert body["done"] is True


def test_patch_task_partial_noop_preserves_fields(client: TestClient) -> None:
    created = client.post("/tasks", json={"title": "keep"}).json()
    r = client.patch(f"/tasks/{created['id']}", json={})
    assert r.status_code == 200
    assert r.json()["title"] == "keep"
    assert r.json()["done"] is False


def test_patch_task_missing_returns_404(client: TestClient) -> None:
    r = client.patch("/tasks/9999", json={"title": "x"})
    assert r.status_code == 404


def test_delete_task_then_404(client: TestClient) -> None:
    created = client.post("/tasks", json={"title": "to delete"}).json()
    r = client.delete(f"/tasks/{created['id']}")
    assert r.status_code == 204
    r2 = client.get(f"/tasks/{created['id']}")
    assert r2.status_code == 404


def test_delete_task_missing_returns_404(client: TestClient) -> None:
    r = client.delete("/tasks/9999")
    assert r.status_code == 404


def test_create_task_validation_rejects_empty_title(client: TestClient) -> None:
    r = client.post("/tasks", json={"title": ""})
    assert r.status_code == 422


def test_list_tasks_after_inserts_is_ordered(client: TestClient) -> None:
    for t in ("a", "b", "c"):
        client.post("/tasks", json={"title": t})
    titles = [t["title"] for t in client.get("/tasks").json()]
    assert titles == ["a", "b", "c"]
