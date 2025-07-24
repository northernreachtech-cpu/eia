// import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import Card from "../components/Card";
// import Button from "../components/Button";

const REGISTRATION_FORM_URL =
  "https://docs.google.com/forms/d/e/1FAIpQLScu4X0hdAIHvZD--v2kaSdPBxQaFeCwSZdcbISlq8GfVZ9TTw/viewform?usp=sharing&ouid=116806761147726279171";
const FEEDBACK_FORM_URL = "https://forms.gle/dTuhRgj9JWe9YYjQ8";

const SUIWorkshop = () => {
  const account = useCurrentAccount();

  return (
    <div className="min-h-screen bg-black pt-24 pb-10">
      <div className="container mx-auto px-4 max-w-2xl">
        <h1 className="text-3xl sm:text-4xl font-livvic font-bold mb-6 text-center">
          SUI Workshop
          <span className="ml-2 px-2 py-0.5 text-xs rounded bg-gradient-to-r from-primary to-secondary text-white font-bold uppercase align-middle">
            Exclusive
          </span>
        </h1>
        <p className="text-white/80 text-center mb-8 max-w-xl mx-auto">
          Welcome to the SUI Workshop! Please register or leave feedback below.
          Only users with a connected wallet can participate.
        </p>
        {!account ? (
          <div className="text-center text-white/60 py-12">
            Please connect your wallet to access the workshop forms.
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card className="p-8 flex flex-col items-center text-center">
              <h2 className="text-xl font-livvic font-bold mb-2">
                Registration
              </h2>
              <p className="text-white/70 mb-4">
                Sign up for the SUI Workshop and get exclusive updates.
              </p>
              <a
                href={REGISTRATION_FORM_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full inline-block bg-primary text-white font-bold py-3 rounded-lg text-center transition hover:bg-secondary focus:outline-none focus:ring-2 focus:ring-primary/40"
              >
                Fill Registration
              </a>
            </Card>
            <Card className="p-8 flex flex-col items-center text-center">
              <h2 className="text-xl font-livvic font-bold mb-2">Feedback</h2>
              <p className="text-white/70 mb-4">
                Already attended? Let us know your thoughts!
              </p>
              <a
                href={FEEDBACK_FORM_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full inline-block bg-primary text-white font-bold py-3 rounded-lg text-center transition hover:bg-secondary focus:outline-none focus:ring-2 focus:ring-primary/40"
              >
                Leave Feedback
              </a>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
};

export default SUIWorkshop;
