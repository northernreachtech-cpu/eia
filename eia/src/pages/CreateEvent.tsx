import { useState, useEffect } from "react";
import {
  MapPin,
  Users,
  Image,
  FileText,
  ChevronLeft,
  ChevronRight,
  Loader2,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useEIAProtocolSDK } from "../lib/sdk";
import Button from "../components/Button";
import Card from "../components/Card";
import useScrollToTop from "../hooks/useScrollToTop";
import { suiClient } from "../config/sui";

// Get ImgBB API key from environment variable
const IMGBB_KEY = import.meta.env.VITE_IMGBB_API_KEY;

const CreateEvent = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useEIAProtocolSDK();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    location: "",
    date: "",
    time: "",
    maxAttendees: "",
    bannerImage: null as File | null,
    imageUrl: "", // Added for IPFS URL
    previewUrl: "", // Add this for local preview
  });
  const [profileId, setProfileId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploadingImage, setUploadingImage] = useState(false);

  // Fetch profile ID on component mount
  useEffect(() => {
    const fetchProfileId = async () => {
      if (!currentAccount) return;

      try {
        setLoading(true);
        // Get organizer's OrganizerCap objects
        const { data: objects } = await suiClient.getOwnedObjects({
          owner: currentAccount.address,
          filter: {
            StructType: `${sdk.eventManagement.getPackageId()}::event_management::OrganizerCap`,
          },
          options: { showContent: true },
        });

        if (objects.length === 0) {
          navigate("/create-organizer-profile");
          return;
        }

        // Get profile ID from OrganizerCap
        const obj = objects[0];
        if (obj.data?.content?.dataType === "moveObject") {
          const fields = obj.data.content.fields as any;
          setProfileId(fields.profile_id);
        }
      } catch (error) {
        console.error("Error fetching profile:", error);
        setError("Failed to fetch organizer profile");
      } finally {
        setLoading(false);
      }
    };

    fetchProfileId();
  }, [currentAccount, navigate, sdk]);

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

  const handleImageUpload = async (file: File) => {
    try {
      setUploadingImage(true);

      // Create preview
      const reader = new FileReader();
      reader.onloadend = () => {
        setFormData((prev) => ({
          ...prev,
          bannerImage: file,
          previewUrl: reader.result as string,
        }));
      };
      reader.readAsDataURL(file);

      const formData = new FormData();
      formData.append("image", file);

      const response = await fetch(
        `https://api.imgbb.com/1/upload?key=${IMGBB_KEY}`,
        {
          method: "POST",
          body: formData,
        }
      );

      const data = await response.json();
      const url = data.data.url;
      setFormData((prev) => ({ ...prev, imageUrl: url }));
    } catch (error) {
      console.error("Error uploading image:", error);
      setError("Failed to upload image");
    } finally {
      setUploadingImage(false);
    }
  };

  const handleSubmit = async () => {
    if (!currentAccount) {
      setError("Please connect your wallet");
      return;
    }

    if (!profileId) {
      setError("Organizer profile not found");
      return;
    }

    try {
      setIsSubmitting(true);
      setError("");

      // Convert date and time to timestamp
      const startTime =
        new Date(`${formData.date}T${formData.time}`).getTime() / 1000;
      const endTime = startTime + 3600 * 2; // Default 2 hours duration

      // Create event transaction with actual profileId
      const tx = sdk.eventManagement.createEvent(
        formData.title,
        formData.description,
        formData.location,
        startTime,
        endTime,
        parseInt(formData.maxAttendees) || 100,
        0, // minAttendees
        0, // minCompletionRate
        0, // minAvgRating
        formData.imageUrl || "", // Use uploaded image URL
        "0x2", // eventRegistryId - this is a shared object, using default registry
        profileId // actual profile ID from OrganizerCap
      );

      // Execute transaction
      signAndExecute(
        { transaction: tx },
        {
          onSuccess: (result) => {
            console.log("Event created successfully:", result);
            navigate("/dashboard/organizer");
          },
          onError: (error) => {
            console.error("Error creating event:", error);
            setError("Failed to create event. Please try again.");
          },
        }
      );
    } catch (error) {
      console.error("Error:", error);
      setError("Failed to create event. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="flex items-center gap-2">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
          <span className="text-white">Loading profile...</span>
        </div>
      </div>
    );
  }

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
                <label
                  htmlFor="banner-upload"
                  className="block border-2 border-dashed border-white/20 rounded-lg p-6 sm:p-8 text-center hover:border-primary/50 transition-colors cursor-pointer"
                  onDrop={(e) => {
                    e.preventDefault();
                    const file = e.dataTransfer.files[0];
                    if (file) handleImageUpload(file);
                  }}
                  onDragOver={(e) => e.preventDefault()}
                >
                  {formData.bannerImage ? (
                    <div>
                      <img
                        src={formData.imageUrl || formData.previewUrl}
                        alt="Preview"
                        className="max-h-48 mx-auto mb-2 rounded"
                      />
                      <p className="text-sm text-white/70">
                        Click or drag to replace
                      </p>
                    </div>
                  ) : (
                    <>
                      <Image className="h-10 w-10 sm:h-12 sm:w-12 mx-auto mb-3 sm:mb-4 text-white/50" />
                      <p className="text-white/70 mb-2 text-sm sm:text-base">
                        Drop your banner image here or click to browse
                      </p>
                      <p className="text-xs sm:text-sm text-white/50">
                        PNG, JPG up to 10MB
                      </p>
                    </>
                  )}
                </label>
                <input
                  id="banner-upload"
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) handleImageUpload(file);
                  }}
                />
                {uploadingImage && (
                  <div className="mt-2 text-primary">
                    <Loader2 className="h-4 w-4 animate-spin inline mr-2" />
                    Uploading...
                  </div>
                )}
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

          {/* Add error display and loading state to the UI */}
          {error && <div className="text-red-500 text-sm mt-4">{error}</div>}

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
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Creating...
                  </>
                ) : (
                  "Create Event"
                )}
              </Button>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default CreateEvent;
