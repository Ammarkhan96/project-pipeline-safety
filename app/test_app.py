import unittest
from app import app


class AppTests(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    def test_health(self):
        self.assertEqual(self.client.get("/health").status_code, 200)

    def test_ready(self):
        self.assertEqual(self.client.get("/ready").status_code, 200)

    def test_root_has_version(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("version", response.get_json())


if __name__ == "__main__":
    unittest.main()
