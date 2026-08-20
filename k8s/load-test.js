import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '1m', target: 50 },  // Ramp up to 50 users
        { duration: '3m', target: 200 }, // Spike to 200 concurrent users
        { duration: '1m', target: 0 },   // Scale down
    ],
};

export default function () {
    const res = http.get('https://q9twuzo0b3.execute-api.ap-south-1.amazonaws.com/products');
    check(res, { 'status was 200': (r) => r.status === 200 });
    sleep(1);
}