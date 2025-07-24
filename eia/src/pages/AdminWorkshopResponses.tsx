import { useEffect, useState } from "react";
import Card from "../components/Card";

interface Registration {
  name: string;
  email: string;
  wallet: string;
  submittedAt: string;
}

interface Feedback {
  feedback: string;
  wallet: string;
  submittedAt: string;
}

const getRegistrations = (): Registration[] => {
  try {
    return JSON.parse(localStorage.getItem("suiWorkshopRegistrations") || "[]");
  } catch {
    return [];
  }
};

const getFeedbacks = (): Feedback[] => {
  try {
    return JSON.parse(localStorage.getItem("suiWorkshopFeedbacks") || "[]");
  } catch {
    return [];
  }
};

const AdminWorkshopResponses = () => {
  const [registrations, setRegistrations] = useState<Registration[]>([]);
  const [feedbacks, setFeedbacks] = useState<Feedback[]>([]);

  useEffect(() => {
    setRegistrations(getRegistrations());
    setFeedbacks(getFeedbacks());
  }, []);

  return (
    <div className="min-h-screen bg-black pt-24 pb-10">
      <div className="container mx-auto px-4 max-w-4xl">
        <h1 className="text-3xl sm:text-4xl font-livvic font-bold mb-8 text-center text-primary">
          SUI Workshop Admin Panel
        </h1>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Registrations */}
          <Card className="p-6">
            <h2 className="text-xl font-livvic font-bold mb-4 text-primary">
              Registrations
            </h2>
            {registrations.length === 0 ? (
              <div className="text-white/60 text-center">
                No registrations yet.
              </div>
            ) : (
              <div className="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
                {registrations.map((reg, i) => (
                  <div
                    key={i}
                    className="bg-white/10 rounded-lg p-4 text-white"
                  >
                    <div className="font-bold text-lg font-livvic mb-1">
                      {reg.name}
                    </div>
                    <div className="text-sm mb-1">
                      Email: <span className="font-semibold">{reg.email}</span>
                    </div>
                    <div className="text-xs mb-1 break-all">
                      Wallet: <span className="font-mono">{reg.wallet}</span>
                    </div>
                    <div className="text-xs text-white/60">
                      Submitted: {new Date(reg.submittedAt).toLocaleString()}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Card>
          {/* Feedbacks */}
          <Card className="p-6">
            <h2 className="text-xl font-livvic font-bold mb-4 text-primary">
              Feedbacks
            </h2>
            {feedbacks.length === 0 ? (
              <div className="text-white/60 text-center">No feedbacks yet.</div>
            ) : (
              <div className="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
                {feedbacks.map((fb, i) => (
                  <div
                    key={i}
                    className="bg-white/10 rounded-lg p-4 text-white"
                  >
                    <div className="mb-2">{fb.feedback}</div>
                    <div className="text-xs mb-1 break-all">
                      Wallet: <span className="font-mono">{fb.wallet}</span>
                    </div>
                    <div className="text-xs text-white/60">
                      Submitted: {new Date(fb.submittedAt).toLocaleString()}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
};

export default AdminWorkshopResponses;
