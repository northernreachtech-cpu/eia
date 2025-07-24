import { useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Menu, X } from "lucide-react";
import ConnectWalletButton from "./ConnectWalletButton";
import { cn } from "../utils/cn";

const Navbar = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const location = useLocation();

  const navLinks = [
    { name: "Events", href: "/events" },
    { name: "My Events", href: "/my-events" },
    { name: "Create Event", href: "/event/create" },
    { name: "Organizers", href: "/organizers" },
    { name: "Sponsor", href: "/sponsor" },
    { name: "SUI Workshop", href: "/sui-workshop", exclusive: true }, // Added SUI Workshop link
    { name: "Profile", href: "/profile/organizer/create" },
    // { name: "Community", href: "/community" },
  ];

  const isActiveLink = (href: string) => {
    return location.pathname === href;
  };

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 card-glass border-b border-white/10">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div className="flex items-center">
            <Link
              to="/"
              className="text-2xl font-livvic font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text"
            >
              Ariya
            </Link>
          </div>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-8 font-open-sans">
            {navLinks.map((link) => (
              <Link
                key={link.name}
                to={link.href}
                className={cn(
                  "transition-colors duration-200",
                  isActiveLink(link.href)
                    ? "text-primary"
                    : "text-white/80 hover:text-white"
                )}
              >
                {link.name}
                {link.exclusive && (
                  <span className="ml-2 px-2 py-0.5 text-xs rounded bg-gradient-to-r from-primary to-secondary text-white font-bold uppercase align-middle">
                    Exclusive
                  </span>
                )}
              </Link>
            ))}
          </div>

          {/* Connect Wallet Button (desktop only) */}
          <div className="hidden md:flex">
            <ConnectWalletButton />
          </div>

          {/* Mobile menu button */}
          <div className="md:hidden">
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="text-white hover:text-primary transition-colors"
            >
              {isMenuOpen ? <X size={24} /> : <Menu size={24} />}
            </button>
          </div>
        </div>

        {/* Mobile Navigation */}
        <div
          className={cn(
            "md:hidden transition-all duration-300 overflow-hidden font-open-sans relative z-50",
            isMenuOpen ? "max-h-96 pb-4" : "max-h-0"
          )}
        >
          <div className="pt-4 space-y-4">
            {navLinks.map((link) => (
              <Link
                key={link.name}
                to={link.href}
                className={cn(
                  "block transition-colors duration-200",
                  isActiveLink(link.href)
                    ? "text-primary"
                    : "text-white/80 hover:text-white"
                )}
                onClick={() => setIsMenuOpen(false)}
              >
                {link.name}
                {link.exclusive && (
                  <span className="ml-2 px-2 py-0.5 text-xs rounded bg-gradient-to-r from-primary to-secondary text-white font-bold uppercase align-middle">
                    Exclusive
                  </span>
                )}
              </Link>
            ))}
            <div className="pt-4">
              <ConnectWalletButton />
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
