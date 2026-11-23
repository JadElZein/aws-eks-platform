import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL;
if (!BASE_URL) {
  throw new Error('set BASE_URL, e.g. -e BASE_URL=http://<alb-hostname>');
}

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 30,
      timeUnit: '1m',
      preAllocatedVUs: 20,
      maxVUs: 60,
      stages: [
        { target: 30, duration: '1m' },
        { target: 180, duration: '2m' },
        { target: 180, duration: '5m' },
        { target: 30, duration: '1m' },
        { target: 30, duration: '6m' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/work?ms=100`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
