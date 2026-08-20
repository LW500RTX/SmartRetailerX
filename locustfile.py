from locust import HttpUser, task, between

class SmartRetailUser(HttpUser):
    wait_time = between(1, 2)
    host = "https://q9twuzo0b3.execute-api.ap-south-1.amazonaws.com"

    @task
    def get_products(self):
        self.client.get("/products")
