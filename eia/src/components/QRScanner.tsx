import { useState, useRef, useEffect } from "react";
import { X, CheckCircle, AlertCircle } from "lucide-react";
import {
  Html5QrcodeScanner,
  Html5QrcodeScanType,
  Html5QrcodeSupportedFormats,
} from "html5-qrcode";
import Button from "./Button";

interface QRScannerProps {
  isOpen: boolean;
  onClose: () => void;
  onScan: (data: any) => void;
  eventId: string;
}

const QRScanner = ({ isOpen, onClose, onScan, eventId }: QRScannerProps) => {
  const [_scanning, setScanning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);
  const scannerContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen) {
      startScanner();
    } else {
      stopScanner();
    }
  }, [isOpen]);

  const startScanner = () => {
    try {
      setError(null);
      setScanning(true);

      if (!scannerContainerRef.current) return;

      scannerRef.current = new Html5QrcodeScanner(
        "qr-scanner-container",
        {
          fps: 10,
          qrbox: { width: 200, height: 200 },
          aspectRatio: 1.0,
          showTorchButtonIfSupported: true,
          supportedScanTypes: [
            Html5QrcodeScanType.SCAN_TYPE_CAMERA,
            Html5QrcodeScanType.SCAN_TYPE_FILE,
          ],
          formatsToSupport: [Html5QrcodeSupportedFormats.QR_CODE],
        },
        false
      );

      scannerRef.current.render(
        (decodedText) => {
          try {
            console.log("QR Code detected:", decodedText);

            const qrData = JSON.parse(decodedText);
            console.log("Parsed QR data:", qrData);
            handleScanResult(qrData);
          } catch (err) {
            console.error("QR parsing error:", err);
            setError("Invalid QR code format");
          }
        },
        (errorMessage) => {
          console.log("QR scanning error:", errorMessage);
          // Don't show NotFoundException errors as they're normal during scanning
          if (
            typeof errorMessage === "string" &&
            !errorMessage.includes("NotFoundException")
          ) {
            setError(`Scanning error: ${errorMessage}`);
          }
        }
      );
    } catch (err) {
      console.error("Scanner start error:", err);
      setError("Failed to start QR scanner");
      setScanning(false);
    }
  };

  const stopScanner = () => {
    if (scannerRef.current) {
      scannerRef.current.clear();
      scannerRef.current = null;
    }
    setScanning(false);
  };

  const handleScanResult = (data: any) => {
    try {
      console.log("handleScanResult received data:", data);

      // If data is a string, parse it
      const parsedData = typeof data === "string" ? JSON.parse(data) : data;
      console.log("Parsed data for validation:", parsedData);

      console.log("Comparing event IDs:", {
        qrEventId: parsedData.event_id,
        currentEventId: eventId,
        match: parsedData.event_id === eventId,
      });

      // Validate QR data
      if (!parsedData.event_id) {
        setError("QR code missing event_id");
        return;
      }

      if (parsedData.event_id !== eventId) {
        setError(
          `Invalid QR code for this event. Expected: ${eventId}, Got: ${parsedData.event_id}`
        );
        return;
      }

      setSuccess("QR code scanned successfully!");
      setTimeout(() => {
        onScan(parsedData);
        onClose();
      }, 1500);
    } catch (err) {
      setError("Invalid QR code format");
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 rounded-lg max-w-lg w-full p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-white">Scan QR Code</h3>
          <Button variant="ghost" size="sm" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>

        {/* Scanner Area */}
        <div className="relative bg-black rounded-lg overflow-hidden mb-4">
          <div
            ref={scannerContainerRef}
            id="qr-scanner-container"
            className="w-full h-80"
          />
        </div>

        {/* Status Messages */}
        {error && (
          <div className="flex items-center gap-2 text-red-400 mb-4">
            <AlertCircle className="h-4 w-4" />
            <span className="text-sm">{error}</span>
          </div>
        )}

        {success && (
          <div className="flex items-center gap-2 text-green-400 mb-4">
            <CheckCircle className="h-4 w-4" />
            <span className="text-sm">{success}</span>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() => {
              console.log("Testing QR code contents...");
              // Simulate a test QR code scan with the same structure as real QR codes
              const testData = {
                event_id: eventId,
                user_address: "0x1234567890abcdef",
                pass_hash: "a1b2c3d4e5f6", // Hex string like real pass hash
                registered_at: Date.now(),
                timestamp: Date.now(),
              };
              console.log("Test QR data:", testData);
              console.log("Test QR JSON string:", JSON.stringify(testData));
              handleScanResult(testData);
            }}
          >
            Test QR Data
          </Button>
        </div>

        <p className="text-xs text-white/60 mt-3 text-center">
          Point camera at attendee's QR code to check them in
        </p>
      </div>
    </div>
  );
};

export default QRScanner;
