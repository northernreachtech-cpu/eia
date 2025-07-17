import { useState } from "react";
import {
  MapPin,
  Users,
  Image,
  FileText,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import Button from "../components/Button";
import Card from "../components/Card";
import useScrollToTop from "../hooks/useScrollToTop";

const CreateEvent = () => {
  useScrollToTop();
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    location: "",
    date: "",
    time: "",
    maxAttendees: "",
    bannerImage: null as File | null,
  });

  const steps = [
    { id: 1, title: "Basic Info", icon: FileText },
    { id: 2, title: "Details", icon: MapPin },
    { id: 3, title: "Media", icon: Image },
    { id: 4, title: "Review", icon: Users },
  ];

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const nextStep = () => {
    if (currentStep < steps.length) {
      setCurrentStep(currentStep + 1);
    }
  };

  const prevStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleSubmit = () => {
    // TODO: Implement event creation logic
    console.log("Creating event:", formData);
  };

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4 max-w-4xl">
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-3xl sm:text-4xl font-satoshi font-bold mb-2 sm:mb-4">
            Create Your Event
          </h1>
          <p className="text-white/80 text-sm sm:text-base">
            Set up your decentralized event in a few simple steps
          </p>
        </div>

        {/* Mobile Progress Steps - Horizontal scroll on mobile */}
        <div className="mb-6 sm:mb-8">
          {/* Desktop version - hidden on mobile */}
          <div className="hidden sm:flex justify-center">
            <div className="flex items-center space-x-4">
              {steps.map((step, index) => (
                <div key={step.id} className="flex items-center">
                  <div
                    className={`
                    w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold
                    ${
                      currentStep >= step.id
                        ? "bg-gradient-to-r from-primary to-secondary text-white"
                        : "bg-white/10 text-white/50"
                    }
                  `}
                  >
                    {step.id}
                  </div>
                  <span
                    className={`ml-2 text-sm ${
                      currentStep >= step.id ? "text-white" : "text-white/50"
                    }`}
                  >
                    {step.title}
                  </span>
                  {index < steps.length - 1 && (
                    <div
                      className={`w-8 h-0.5 mx-4 ${
                        currentStep > step.id ? "bg-primary" : "bg-white/20"
                      }`}
                    />
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Mobile version - current step indicator */}
          <div className="flex sm:hidden justify-between items-center bg-white/5 rounded-lg p-4">
            <div className="flex items-center">
              <div className="w-8 h-8 rounded-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center text-sm font-bold mr-3">
                {currentStep}
              </div>
              <div>
                <div className="text-sm font-semibold">
                  {steps[currentStep - 1].title}
                </div>
                <div className="text-xs text-white/60">
                  Step {currentStep} of {steps.length}
                </div>
              </div>
            </div>
            <div className="text-xs text-white/60">
              {Math.round((currentStep / steps.length) * 100)}%
            </div>
          </div>

          {/* Mobile progress bar */}
          <div className="sm:hidden mt-3">
            <div className="w-full bg-white/10 rounded-full h-1">
              <div
                className="bg-gradient-to-r from-primary to-secondary h-1 rounded-full transition-all duration-300"
                style={{ width: `${(currentStep / steps.length) * 100}%` }}
              />
            </div>
          </div>
        </div>

        <Card className="p-4 sm:p-6 lg:p-8">
          {/* Step 1: Basic Info */}
          {currentStep === 1 && (
            <div className="space-y-4 sm:space-y-6">
              <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">
                Event Basic Information
              </h3>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Event Title
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => handleInputChange("title", e.target.value)}
                  className="w-full px-4 py-3 sm:py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base"
                  placeholder="Enter event title"
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Description
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) =>
                    handleInputChange("description", e.target.value)
                  }
                  rows={4}
                  className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base resize-none"
                  placeholder="Describe your event"
                />
              </div>
            </div>
          )}

          {/* Step 2: Details */}
          {currentStep === 2 && (
            <div className="space-y-4 sm:space-y-6">
              <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">
                Event Details
              </h3>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Location
                </label>
                <input
                  type="text"
                  value={formData.location}
                  onChange={(e) =>
                    handleInputChange("location", e.target.value)
                  }
                  className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base"
                  placeholder="Enter event location"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Date</label>
                  <input
                    type="date"
                    value={formData.date}
                    onChange={(e) => handleInputChange("date", e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-2">Time</label>
                  <input
                    type="time"
                    value={formData.time}
                    onChange={(e) => handleInputChange("time", e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Max Attendees (Optional)
                </label>
                <input
                  type="number"
                  value={formData.maxAttendees}
                  onChange={(e) =>
                    handleInputChange("maxAttendees", e.target.value)
                  }
                  className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus:border-primary focus:outline-none text-sm sm:text-base"
                  placeholder="No limit"
                />
              </div>
            </div>
          )}

          {/* Step 3: Media */}
          {currentStep === 3 && (
            <div className="space-y-4 sm:space-y-6">
              <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">
                Event Media
              </h3>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Banner Image
                </label>
                <div className="border-2 border-dashed border-white/20 rounded-lg p-6 sm:p-8 text-center hover:border-primary/50 transition-colors">
                  <Image className="h-10 w-10 sm:h-12 sm:w-12 mx-auto mb-3 sm:mb-4 text-white/50" />
                  <p className="text-white/70 mb-2 text-sm sm:text-base">
                    Drop your banner image here or click to browse
                  </p>
                  <p className="text-xs sm:text-sm text-white/50">
                    PNG, JPG up to 10MB
                  </p>
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) {
                        setFormData((prev) => ({ ...prev, bannerImage: file }));
                      }
                    }}
                  />
                </div>
              </div>
            </div>
          )}

          {/* Step 4: Review */}
          {currentStep === 4 && (
            <div className="space-y-4 sm:space-y-6">
              <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">
                Review Your Event
              </h3>

              <div className="space-y-3 sm:space-y-4">
                <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                  <h4 className="font-semibold text-primary text-sm sm:text-base">
                    Event Title
                  </h4>
                  <p className="text-sm sm:text-base">
                    {formData.title || "Not specified"}
                  </p>
                </div>

                <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                  <h4 className="font-semibold text-primary text-sm sm:text-base">
                    Description
                  </h4>
                  <p className="text-sm sm:text-base">
                    {formData.description || "Not specified"}
                  </p>
                </div>

                <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                  <h4 className="font-semibold text-primary text-sm sm:text-base">
                    Location
                  </h4>
                  <p className="text-sm sm:text-base">
                    {formData.location || "Not specified"}
                  </p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
                  <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                    <h4 className="font-semibold text-primary text-sm sm:text-base">
                      Date
                    </h4>
                    <p className="text-sm sm:text-base">
                      {formData.date || "Not specified"}
                    </p>
                  </div>
                  <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                    <h4 className="font-semibold text-primary text-sm sm:text-base">
                      Time
                    </h4>
                    <p className="text-sm sm:text-base">
                      {formData.time || "Not specified"}
                    </p>
                  </div>
                </div>

                <div className="border border-white/20 rounded-lg p-3 sm:p-4">
                  <h4 className="font-semibold text-primary text-sm sm:text-base">
                    Max Attendees
                  </h4>
                  <p className="text-sm sm:text-base">
                    {formData.maxAttendees || "Unlimited"}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Navigation Buttons */}
          <div className="flex flex-col sm:flex-row justify-between items-center mt-6 sm:mt-8 gap-3 sm:gap-0">
            <Button
              variant="ghost"
              onClick={prevStep}
              disabled={currentStep === 1}
              className="w-full sm:w-auto order-2 sm:order-1"
            >
              <ChevronLeft className="mr-2 h-4 w-4" />
              Previous
            </Button>

            {currentStep < steps.length ? (
              <Button
                onClick={nextStep}
                className="w-full sm:w-auto order-1 sm:order-2"
                size="lg"
              >
                Next
                <ChevronRight className="ml-2 h-4 w-4" />
              </Button>
            ) : (
              <Button
                onClick={handleSubmit}
                className="w-full sm:w-auto order-1 sm:order-2"
                size="lg"
              >
                Create Event
              </Button>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default CreateEvent;
