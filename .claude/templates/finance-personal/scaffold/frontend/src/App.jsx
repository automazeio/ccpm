import { useState, useEffect } from 'react';

function App() {
  const [message, setMessage] = useState('Loading...');
  const [health, setHealth] = useState(null);

  useEffect(() => {
    fetch('/api')
      .then(res => res.json())
      .then(data => setMessage(data.message))
      .catch(() => setMessage('Error connecting to backend'));

    fetch('/api/status')
      .then(res => res.json())
      .then(data => setHealth(data))
      .catch(() => {});
  }, []);

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Finance Personal</h1>
      <p>{message}</p>
      {health && (
        <div style={{ marginTop: '1rem', padding: '1rem', background: '#f0f0f0', borderRadius: '8px' }}>
          <h3>Service Status</h3>
          <p>Service: {health.service}</p>
          <p>Version: {health.version}</p>
          <p>Environment: {health.environment}</p>
        </div>
      )}
    </div>
  );
}

export default App;
