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
          qrbox: { width: 250, height: 250 }, // Larger scan area
          aspectRatio: 1.0,
          showTorchButtonIfSupported: true,
          supportedScanTypes: [
            Html5QrcodeScanType.SCAN_TYPE_CAMERA,
            Html5QrcodeScanType.SCAN_TYPE_FILE,
          ],
          formatsToSupport: [
            Html5QrcodeSupportedFormats.QR_CODE,
            Html5QrcodeSupportedFormats.AZTEC,
            Html5QrcodeSupportedFormats.CODABAR,
            Html5QrcodeSupportedFormats.CODE_39,
            Html5QrcodeSupportedFormats.CODE_93,
            Html5QrcodeSupportedFormats.CODE_128,
            Html5QrcodeSupportedFormats.DATA_MATRIX,
            Html5QrcodeSupportedFormats.MAXICODE,
            Html5QrcodeSupportedFormats.ITF,
            Html5QrcodeSupportedFormats.EAN_13,
            Html5QrcodeSupportedFormats.EAN_8,
            Html5QrcodeSupportedFormats.PDF_417,
            Html5QrcodeSupportedFormats.RSS_14,
            Html5QrcodeSupportedFormats.RSS_EXPANDED,
            Html5QrcodeSupportedFormats.UPC_A,
            Html5QrcodeSupportedFormats.UPC_E,
            Html5QrcodeSupportedFormats.UPC_EAN_EXTENSION,
          ],
          experimentalFeatures: {
            useBarCodeDetectorIfSupported: true,
          },
        },
        false
      );

      scannerRef.current.render(
        (decodedText) => {
          console.log("=== QR CODE SCANNED ===");
          console.log("Raw decoded text:", decodedText);
          console.log("Decoded text type:", typeof decodedText);
          console.log("Decoded text length:", decodedText.length);
          console.log("First 100 characters:", decodedText.substring(0, 100));

          try {
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

          // Provide more helpful error messages
          if (typeof errorMessage === "string") {
            if (errorMessage.includes("NotFoundException")) {
              // This is normal during scanning, don't show error
              return;
            } else if (errorMessage.includes("NotAllowedError")) {
              setError(
                "Camera access denied. Please allow camera permissions."
              );
            } else if (errorMessage.includes("NotFoundError")) {
              setError(
                "No camera found. Please connect a camera and try again."
              );
            } else if (errorMessage.includes("NotSupportedError")) {
              setError(
                "Camera not supported. Please try a different browser or device."
              );
            } else if (errorMessage.includes("NotReadableError")) {
              setError(
                "Camera is in use by another application. Please close other camera apps."
              );
            } else {
              setError(`Scanning error: ${errorMessage}`);
            }
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

      // Log the structure to understand the new format
      console.log("QR Data structure:", {
        hasRef: !!parsedData.ref,
        hasEventId: !!parsedData.e,
        hasPassId: !!parsedData.p,
        hasUserAddress: !!parsedData.u,
        hasTimestamp: !!parsedData.t,
      });

      console.log("Comparing event IDs:", {
        qrEventId: parsedData.e,
        currentEventId: eventId,
        match: parsedData.e === eventId,
      });

      // Validate QR data structure
      if (!parsedData.e) {
        setError("QR code missing event_id");
        return;
      }

      if (!parsedData.p) {
        setError("QR code missing pass_id");
        return;
      }

      if (!parsedData.u) {
        setError("QR code missing user_address");
        return;
      }

      if (parsedData.e !== eventId) {
        setError(
          `Invalid QR code for this event. Expected: ${eventId}, Got: ${parsedData.e}`
        );
        return;
      }

      // Reconstruct the full data structure for check-in
      const fullData = {
        event_id: parsedData.e,
        user_address: parsedData.u,
        pass_id: parsedData.p,
        pass_hash: null, // Will be generated from pass_id
        timestamp: parsedData.t,
        reference: parsedData.ref,
      };

      console.log("Reconstructed full data:", fullData);

      setSuccess("QR code scanned successfully!");
      setTimeout(() => {
        onScan(fullData);
        onClose();
      }, 1500);
    } catch (err) {
      console.error("Error in handleScanResult:", err);
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
              // Simulate a test QR code scan with the new structure (base64 pass_hash)
              const testPassHash = new Uint8Array([
                1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
              ]);
              const testPassHashBase64 = btoa(
                String.fromCharCode(...testPassHash)
              );

              const testData = {
                event_id: eventId,
                user_address: "0x1234567890abcdef",
                pass_hash: testPassHashBase64, // Base64 encoded Uint8Array
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
