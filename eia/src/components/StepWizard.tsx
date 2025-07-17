import { type ReactNode } from "react";
import { Check, ChevronRight } from "lucide-react";

interface Step {
  id: string;
  title: string;
  description?: string;
  icon?: ReactNode;
}

interface StepWizardProps {
  steps: Step[];
  currentStep: number;
  onStepClick?: (stepIndex: number) => void;
  allowClickableSteps?: boolean;
  className?: string;
}

const StepWizard = ({
  steps,
  currentStep,
  onStepClick,
  allowClickableSteps = false,
  className = "",
}: StepWizardProps) => {
  const isStepCompleted = (stepIndex: number) => stepIndex < currentStep;
  const isStepActive = (stepIndex: number) => stepIndex === currentStep;
  const isStepClickable = (stepIndex: number) =>
    allowClickableSteps && onStepClick && stepIndex <= currentStep;

  return (
    <div className={`w-full ${className}`}>
      {/* Desktop Horizontal Layout */}
      <div className="hidden md:flex items-center justify-between">
        {steps.map((step, index) => (
          <div key={step.id} className="flex items-center flex-1">
            {/* Step Circle */}
            <div
              className={`
                relative flex items-center justify-center w-12 h-12 rounded-full border-2 transition-all duration-300
                ${
                  isStepCompleted(index)
                    ? "bg-gradient-to-r from-primary to-secondary border-primary text-white"
                    : isStepActive(index)
                    ? "border-primary text-primary bg-primary/10"
                    : "border-white/20 text-white/40 bg-white/5"
                }
                ${
                  isStepClickable(index) ? "cursor-pointer hover:scale-105" : ""
                }
              `}
              onClick={() => isStepClickable(index) && onStepClick!(index)}
            >
              {isStepCompleted(index) ? (
                <Check className="h-6 w-6" />
              ) : step.icon ? (
                step.icon
              ) : (
                <span className="font-semibold">{index + 1}</span>
              )}
            </div>

            {/* Step Content */}
            <div className="ml-4 flex-1">
              <div
                className={`
                  font-medium transition-colors duration-300
                  ${
                    isStepCompleted(index) || isStepActive(index)
                      ? "text-white"
                      : "text-white/60"
                  }
                  ${
                    isStepClickable(index)
                      ? "cursor-pointer hover:text-primary"
                      : ""
                  }
                `}
                onClick={() => isStepClickable(index) && onStepClick!(index)}
              >
                {step.title}
              </div>
              {step.description && (
                <div className="text-sm text-white/50 mt-1">
                  {step.description}
                </div>
              )}
            </div>

            {/* Connector Line */}
            {index < steps.length - 1 && (
              <div className="flex items-center mx-4">
                <div
                  className={`
                    h-px w-16 transition-colors duration-300
                    ${
                      isStepCompleted(index)
                        ? "bg-gradient-to-r from-primary to-secondary"
                        : "bg-white/20"
                    }
                  `}
                />
                <ChevronRight
                  className={`
                    h-4 w-4 ml-2 transition-colors duration-300
                    ${isStepCompleted(index) ? "text-primary" : "text-white/20"}
                  `}
                />
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Mobile Vertical Layout */}
      <div className="md:hidden space-y-4">
        {steps.map((step, index) => (
          <div key={step.id} className="flex items-start">
            {/* Step Circle */}
            <div
              className={`
                relative flex items-center justify-center w-10 h-10 rounded-full border-2 transition-all duration-300 flex-shrink-0
                ${
                  isStepCompleted(index)
                    ? "bg-gradient-to-r from-primary to-secondary border-primary text-white"
                    : isStepActive(index)
                    ? "border-primary text-primary bg-primary/10"
                    : "border-white/20 text-white/40 bg-white/5"
                }
                ${isStepClickable(index) ? "cursor-pointer" : ""}
              `}
              onClick={() => isStepClickable(index) && onStepClick!(index)}
            >
              {isStepCompleted(index) ? (
                <Check className="h-5 w-5" />
              ) : step.icon ? (
                step.icon
              ) : (
                <span className="font-semibold text-sm">{index + 1}</span>
              )}
            </div>

            {/* Step Content */}
            <div className="ml-4 flex-1 pb-4">
              <div
                className={`
                  font-medium transition-colors duration-300
                  ${
                    isStepCompleted(index) || isStepActive(index)
                      ? "text-white"
                      : "text-white/60"
                  }
                  ${
                    isStepClickable(index)
                      ? "cursor-pointer hover:text-primary"
                      : ""
                  }
                `}
                onClick={() => isStepClickable(index) && onStepClick!(index)}
              >
                {step.title}
              </div>
              {step.description && (
                <div className="text-sm text-white/50 mt-1">
                  {step.description}
                </div>
              )}

              {/* Vertical Connector Line */}
              {index < steps.length - 1 && (
                <div
                  className={`
                    w-px h-8 ml-[-20px] mt-2 transition-colors duration-300
                    ${
                      isStepCompleted(index)
                        ? "bg-gradient-to-b from-primary to-secondary"
                        : "bg-white/20"
                    }
                  `}
                />
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default StepWizard;
