import { useState, useEffect } from "react";
import { X, Download } from "lucide-react";
import QRCode from "qrcode";
import Card from "./Card";
import Button from "./Button";

interface QRDisplayProps {
  qrData: string;
  eventName: string;
  isOpen: boolean;
  onClose: () => void;
}

const QRDisplay = ({ qrData, eventName, isOpen, onClose }: QRDisplayProps) => {
  const [qrCodeUrl, setQrCodeUrl] = useState<string>("");

  useEffect(() => {
    if (isOpen && qrData) {
      console.log("Generating QR code with data:", qrData);
      console.log("QR data type:", typeof qrData);

      // qrData is already a JSON string, don't double-encode it
      const dataToEncode =
        typeof qrData === "string" ? qrData : JSON.stringify(qrData);
      console.log("Data to encode in QR:", dataToEncode);

      // Generate QR code locally using qrcode library with simpler options
      QRCode.toDataURL(dataToEncode, {
        width: 256,
        margin: 0,
        color: {
          dark: "#000000",
          light: "#FFFFFF",
        },
        errorCorrectionLevel: "L", // Lower error correction for better compatibility
      })
        .then((url) => {
          console.log("QR code generated successfully");
          setQrCodeUrl(url);
        })
        .catch((err) => {
          console.error("Error generating QR code:", err);
          // Fallback to external service
          const fallbackUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(
            dataToEncode
          )}`;
          setQrCodeUrl(fallbackUrl);
        });
    }
  }, [isOpen, qrData]);

  const handleDownload = () => {
    if (qrCodeUrl) {
      const link = document.createElement("a");
      link.href = qrCodeUrl;
      link.download = `qr-code-${eventName}.png`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
      <div onClick={(e) => e.stopPropagation()}>
        <Card className="p-8 max-w-sm mx-4">
          <div className="text-center">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-semibold">Event QR Code</h3>
              <button
                onClick={onClose}
                className="text-white/60 hover:text-white"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="bg-white p-4 rounded-lg mb-4">
              {qrCodeUrl ? (
                <img
                  src={qrCodeUrl}
                  alt="QR Code"
                  className="w-48 h-48 mx-auto"
                />
              ) : (
                <div className="w-48 h-48 bg-gray-200 rounded flex items-center justify-center">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                </div>
              )}
            </div>

            <p className="text-white/70 text-sm mb-4">
              Show this QR code to the event organizer for check-in
            </p>

            <div className="space-y-2">
              <Button onClick={handleDownload} className="w-full">
                <Download className="mr-2 h-4 w-4" />
                Download QR Code
              </Button>
              <Button variant="outline" onClick={onClose} className="w-full">
                Close
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};

export default QRDisplay;
