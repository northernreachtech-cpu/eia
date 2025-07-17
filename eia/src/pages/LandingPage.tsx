import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { Calendar, Users, Shield, Award, QrCode, Coins } from "lucide-react";
import Button from "../components/Button";
import Card from "../components/Card";
import useScrollToTop from "../hooks/useScrollToTop";

const LandingPage = () => {
  useScrollToTop();

  const features = [
    {
      icon: <Calendar className="h-8 w-8 text-primary" />,
      title: "Create Events",
      description:
        "Set up decentralized events with wallet-based check-ins and NFT rewards.",
    },
    {
      icon: <QrCode className="h-8 w-8 text-secondary" />,
      title: "QR Check-ins",
      description:
        "Seamless attendance tracking with QR codes and blockchain verification.",
    },
    {
      icon: <Shield className="h-8 w-8 text-accent" />,
      title: "Anonymous Identity",
      description:
        "Maintain privacy while building your on-chain event reputation.",
    },
    {
      icon: <Award className="h-8 w-8 text-primary" />,
      title: "NFT Completion",
      description: "Mint proof-of-attendance NFTs for completed events.",
    },
    {
      icon: <Users className="h-8 w-8 text-secondary" />,
      title: "Convener Discovery",
      description: "Find trusted event organizers with on-chain reputation.",
    },
    {
      icon: <Coins className="h-8 w-8 text-accent" />,
      title: "Sponsor Dashboard",
      description:
        "Track KPIs and manage event sponsorships with escrow protection.",
    },
  ];

  const steps = [
    {
      step: "01",
      title: "Connect Wallet",
      description:
        "Link your Web3 wallet to get started with decentralized events.",
    },
    {
      step: "02",
      title: "Create or Join",
      description: "Create your own event or discover events in your area.",
    },
    {
      step: "03",
      title: "Check-in & Participate",
      description:
        "Use QR codes for seamless check-ins and event participation.",
    },
    {
      step: "04",
      title: "Earn NFT Rewards",
      description:
        "Complete events to mint exclusive NFTs and build your reputation.",
    },
  ];

  return (
    <div className="min-h-screen bg-black">
      {/* Hero Section - Better desktop layout with max-width and improved spacing */}
      <section className="pt-24 sm:pt-32 pb-12 sm:pb-20">
        <div className="container mx-auto px-4">
          <div className="max-w-6xl mx-auto">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              className="text-center"
            >
              <h1 className="text-4xl sm:text-5xl lg:text-7xl xl:text-8xl font-satoshi font-bold mb-4 sm:mb-6 leading-tight">
                <span className="bg-gradient-to-r from-primary via-secondary to-accent text-transparent bg-clip-text">
                  Decentralized
                </span>
                <br />
                Event Protocol
              </h1>
              <p className="text-lg sm:text-xl lg:text-2xl text-white/80 mb-6 sm:mb-8 max-w-4xl mx-auto px-4 leading-relaxed">
                Create, manage, and attend events with blockchain-powered
                check-ins, anonymous identity management, and NFT
                proof-of-attendance.
              </p>
              <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center px-4 max-w-lg mx-auto">
                <Link to="/event/create" className="w-full sm:w-auto">
                  <Button size="lg" className="w-full sm:w-auto">
                    <Calendar className="mr-2 h-5 w-5" />
                    Create Event
                  </Button>
                </Link>
                <Link to="/events" className="w-full sm:w-auto">
                  <Button
                    variant="outline"
                    size="lg"
                    className="w-full sm:w-auto"
                  >
                    <Users className="mr-2 h-5 w-5" />
                    Browse Events
                  </Button>
                </Link>
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Features Section - Better desktop grid layout */}
      <section className="py-12 sm:py-20">
        <div className="container mx-auto px-4">
          <div className="max-w-7xl mx-auto">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              viewport={{ once: true }}
              className="text-center mb-12 sm:mb-16"
            >
              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-satoshi font-bold mb-3 sm:mb-4">
                Powerful Features
              </h2>
              <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-3xl mx-auto px-4 leading-relaxed">
                Everything you need to create, manage, and participate in
                decentralized events
              </p>
            </motion.div>

            {/* Improved grid layout for better desktop appearance */}
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
              {features.map((feature, index) => (
                <motion.div
                  key={feature.title}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.5, delay: index * 0.1 }}
                  viewport={{ once: true }}
                  className="flex"
                >
                  <Card hover className="text-center h-full p-6 sm:p-8 flex-1">
                    <div className="mb-6 flex justify-center">
                      <div className="p-3 rounded-xl bg-white/5">
                        {feature.icon}
                      </div>
                    </div>
                    <h3 className="text-lg sm:text-xl lg:text-2xl font-semibold mb-3 sm:mb-4">
                      {feature.title}
                    </h3>
                    <p className="text-white/70 text-sm sm:text-base lg:text-lg leading-relaxed">
                      {feature.description}
                    </p>
                  </Card>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* How It Works Section - Better desktop step layout */}
      <section className="py-12 sm:py-20">
        <div className="container mx-auto px-4">
          <div className="max-w-7xl mx-auto">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              viewport={{ once: true }}
              className="text-center mb-12 sm:mb-16"
            >
              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-satoshi font-bold mb-3 sm:mb-4">
                How It Works
              </h2>
              <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-3xl mx-auto px-4 leading-relaxed">
                Get started with decentralized events in four simple steps
              </p>
            </motion.div>

            {/* Improved layout for desktop - single row with better spacing */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 sm:gap-8">
              {steps.map((step, index) => (
                <motion.div
                  key={step.step}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.5, delay: index * 0.2 }}
                  viewport={{ once: true }}
                  className="text-center flex flex-col"
                >
                  <div className="mb-4 sm:mb-6">
                    <div className="w-16 h-16 sm:w-20 sm:h-20 lg:w-24 lg:h-24 mx-auto rounded-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center text-xl sm:text-2xl lg:text-3xl font-bold">
                      {step.step}
                    </div>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-lg sm:text-xl lg:text-2xl font-semibold mb-2 sm:mb-3">
                      {step.title}
                    </h3>
                    <p className="text-white/70 text-sm sm:text-base lg:text-lg leading-relaxed">
                      {step.description}
                    </p>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section - Better desktop centering and spacing */}
      <section className="py-12 sm:py-20">
        <div className="container mx-auto px-4 text-center">
          <div className="max-w-5xl mx-auto">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              viewport={{ once: true }}
            >
              <Card className="p-8 sm:p-12 lg:p-16">
                <h2 className="text-2xl sm:text-3xl lg:text-4xl font-satoshi font-bold mb-4 sm:mb-6">
                  Ready to Get Started?
                </h2>
                <p className="text-white/80 text-base sm:text-lg lg:text-xl mb-6 sm:mb-8 max-w-2xl mx-auto leading-relaxed">
                  Join the future of event management with blockchain technology
                </p>
                <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center max-w-lg mx-auto">
                  <Link to="/event/create" className="w-full sm:w-auto">
                    <Button size="lg" className="w-full sm:w-auto">
                      Get Started
                    </Button>
                  </Link>
                  <Link to="/events" className="w-full sm:w-auto">
                    <Button
                      variant="outline"
                      size="lg"
                      className="w-full sm:w-auto"
                    >
                      Explore Events
                    </Button>
                  </Link>
                </div>
              </Card>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Footer - Better desktop layout */}
      <footer className="py-12 sm:py-16 border-t border-white/10">
        <div className="container mx-auto px-4">
          <div className="max-w-6xl mx-auto">
            <div className="flex flex-col md:flex-row justify-between items-center gap-6 md:gap-0">
              <div className="text-center md:text-left">
                <h3 className="text-xl sm:text-2xl font-satoshi font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text">
                  EIA Protocol
                </h3>
                <p className="text-white/60 text-sm sm:text-base mt-1">
                  Decentralized Event Management
                </p>
              </div>
              <div className="flex flex-wrap justify-center md:justify-end gap-6 sm:gap-8 text-sm sm:text-base text-white/60">
                <a href="#" className="hover:text-white transition-colors">
                  Privacy
                </a>
                <a href="#" className="hover:text-white transition-colors">
                  Terms
                </a>
                <a href="#" className="hover:text-white transition-colors">
                  Docs
                </a>
                <a href="#" className="hover:text-white transition-colors">
                  Support
                </a>
              </div>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default LandingPage;
