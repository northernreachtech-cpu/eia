import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { SuiClientProvider, WalletProvider } from "@mysten/dapp-kit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { networkConfig } from "./config/sui";

import Navbar from "./components/Navbar";
import LandingPage from "./pages/LandingPage";
import CreateEvent from "./pages/CreateEvent";
import Events from "./pages/Events";
import MyEventsPage from "./pages/MyEvents";
import EventDetails from "./pages/EventDetails";
import ConvenerMarketplace from "./pages/ConvenerMarketplace";
import OrganizerDashboard from "./pages/OrganizerDashboard";
import SponsorDashboard from "./pages/SponsorDashboard";
import CommunityHub from "./pages/CommunityHub";
import CreateOrganizerProfile from "./pages/CreateOrganizerProfile";
import useScrollToTop from "./hooks/useScrollToTop";

import "@mysten/dapp-kit/dist/index.css";

const queryClient = new QueryClient();

// Main App Component with scroll-to-top
function AppContent() {
  useScrollToTop();

  return (
    <div className="min-h-screen bg-black px-4 py-2 sm:px-6 sm:py-4 lg:px-8 lg:py-6">
      <Navbar />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/events" element={<Events />} />
        <Route path="/my-events" element={<MyEventsPage />} />
        <Route path="/event/create" element={<CreateEvent />} />
        <Route path="/event/:id" element={<EventDetails />} />
        <Route path="/organizers" element={<ConvenerMarketplace />} />
        <Route
          path="/profile/organizer/create"
          element={<CreateOrganizerProfile />}
        />
        <Route path="/dashboard/organizer" element={<OrganizerDashboard />} />
        <Route path="/dashboard/sponsor" element={<SponsorDashboard />} />
        <Route path="/community" element={<CommunityHub />} />
      </Routes>
    </div>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networkConfig} defaultNetwork="testnet">
        <WalletProvider autoConnect>
          <Router>
            <AppContent />
          </Router>
        </WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  );
}

export default App;
