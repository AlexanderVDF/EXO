import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Home from './screens/Home';
import Plans from './screens/Plans';
import NetworkMap from './screens/NetworkMap';
import Devices from './screens/Devices';
import Settings from './screens/Settings';
import useWebSocket from './hooks/useWebSocket';

export default function App() {
  const ws = useWebSocket();

  return (
    <BrowserRouter>
      <div className="flex h-screen bg-exo-bg text-exo-text overflow-hidden">
        <Sidebar />

        {/* Main content area */}
        <main className="ml-[72px] flex-1 flex flex-col overflow-hidden">
          <Routes>
            <Route path="/" element={<Home ws={ws} />} />
            <Route path="/plans" element={<Plans ws={ws} />} />
            <Route path="/network" element={<NetworkMap ws={ws} />} />
            <Route path="/devices" element={<Devices ws={ws} />} />
            <Route path="/settings" element={<Settings ws={ws} />} />
          </Routes>
        </main>

        {/* Connection indicator */}
        {!ws.connected && (
          <div className="fixed bottom-4 right-4 px-4 py-2 rounded-xl bg-red-500/15 text-red-400 text-xs font-medium flex items-center gap-2 animate-fade-in z-50">
            <span className="w-2 h-2 rounded-full bg-red-400 animate-pulse" />
            Connexion WebSocket perdue
          </div>
        )}
      </div>
    </BrowserRouter>
  );
}
