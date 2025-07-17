import { useState, useRef, useCallback } from "react";
import {
  Camera,
  X,
  Flashlight,
  FlashlightOff,
  CheckCircle,
  AlertCircle,
  RefreshCw,
} from "lucide-react";
import Button from "./Button";
import Card from "./Card";

interface QRScannerProps {
  onScan: (data: string) => void;
  onClose?: () => void;
  isOpen?: boolean;
  title?: string;
}

const QRScanner = ({
  onScan,
  onClose,
  isOpen = false,
  title = "Scan QR Code",
}: QRScannerProps) => {
  const [isScanning, setIsScanning] = useState(false);
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [scanResult, setScanResult] = useState<{
    type: "success" | "error";
    message: string;
  } | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  const startScanning = useCallback(async () => {
    try {
      setIsScanning(true);
      setScanResult(null);

      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "environment",
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }
    } catch (error) {
      console.error("Error accessing camera:", error);
      setScanResult({
        type: "error",
        message: "Unable to access camera. Please check permissions.",
      });
      setIsScanning(false);
    }
  }, []);

  const stopScanning = useCallback(() => {
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      stream.getTracks().forEach((track) => track.stop());
      videoRef.current.srcObject = null;
    }
    setIsScanning(false);
    setFlashEnabled(false);
  }, []);

  const toggleFlash = useCallback(async () => {
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      const track = stream.getVideoTracks()[0];

      if (track && "applyConstraints" in track) {
        try {
          await track.applyConstraints({
            advanced: [{ torch: !flashEnabled } as any],
          });
          setFlashEnabled(!flashEnabled);
        } catch (error) {
          console.error("Flash not supported:", error);
        }
      }
    }
  }, [flashEnabled]);

  // Simulate QR code detection (replace with actual QR library)
  const simulateQRScan = useCallback(() => {
    const mockQRData = JSON.stringify({
      eventId: "event-123",
      userId: "user-456",
      timestamp: Date.now(),
    });

    setScanResult({
      type: "success",
      message: "QR Code scanned successfully!",
    });

    setTimeout(() => {
      onScan(mockQRData);
      stopScanning();
    }, 1500);
  }, [onScan, stopScanning]);

  const handleClose = () => {
    stopScanning();
    onClose?.();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/95 backdrop-blur-sm flex items-center justify-center p-4">
      <Card className="w-full max-w-md mx-auto overflow-hidden">
        {/* Header */}
        <div className="p-6 pb-4 bg-gradient-to-r from-primary/10 to-secondary/10 border-b border-white/10">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-xl font-bold text-white">{title}</h3>
              <p className="text-sm text-white/60 mt-1">
                Position QR code within the frame
              </p>
            </div>
            <button
              onClick={handleClose}
              className="p-2 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
            >
              <X className="h-5 w-5 text-white" />
            </button>
          </div>
        </div>

        {/* Scanner Area */}
        <div className="relative bg-black aspect-square overflow-hidden">
          {isScanning ? (
            <>
              <video
                ref={videoRef}
                className="w-full h-full object-cover"
                playsInline
                muted
              />

              {/* Scanning overlay */}
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="relative">
                  {/* Scanning frame */}
                  <div className="w-64 h-64 border-2 border-primary relative">
                    <div className="absolute top-0 left-0 w-8 h-8 border-t-4 border-l-4 border-accent"></div>
                    <div className="absolute top-0 right-0 w-8 h-8 border-t-4 border-r-4 border-accent"></div>
                    <div className="absolute bottom-0 left-0 w-8 h-8 border-b-4 border-l-4 border-accent"></div>
                    <div className="absolute bottom-0 right-0 w-8 h-8 border-b-4 border-r-4 border-accent"></div>

                    {/* Scanning line */}
                    <div className="absolute inset-0 overflow-hidden">
                      <div className="w-full h-0.5 bg-gradient-to-r from-transparent via-accent to-transparent animate-pulse"></div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Flash button */}
              <button
                onClick={toggleFlash}
                className="absolute top-4 right-4 p-3 rounded-full bg-black/50 backdrop-blur-sm text-white hover:bg-black/70 transition-colors"
              >
                {flashEnabled ? (
                  <FlashlightOff className="h-5 w-5" />
                ) : (
                  <Flashlight className="h-5 w-5" />
                )}
              </button>
            </>
          ) : (
            <div className="flex items-center justify-center h-full bg-gradient-to-br from-primary/5 to-secondary/5">
              <div className="text-center">
                <Camera className="h-16 w-16 text-white/30 mx-auto mb-4" />
                <p className="text-white/60 mb-6">Camera not active</p>
                <Button onClick={startScanning} className="mx-auto">
                  <Camera className="mr-2 h-4 w-4" />
                  Start Scanning
                </Button>
              </div>
            </div>
          )}

          {/* Scan result overlay */}
          {scanResult && (
            <div className="absolute inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center">
              <div className="text-center p-6">
                {scanResult.type === "success" ? (
                  <CheckCircle className="h-16 w-16 text-green-400 mx-auto mb-4" />
                ) : (
                  <AlertCircle className="h-16 w-16 text-red-400 mx-auto mb-4" />
                )}
                <p
                  className={`text-lg font-medium ${
                    scanResult.type === "success"
                      ? "text-green-400"
                      : "text-red-400"
                  }`}
                >
                  {scanResult.message}
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Controls */}
        <div className="p-6 bg-gradient-to-r from-white/5 to-white/10 border-t border-white/10">
          <div className="flex gap-3">
            {isScanning && (
              <Button
                variant="outline"
                onClick={simulateQRScan}
                className="flex-1"
              >
                Simulate Scan
              </Button>
            )}

            <Button
              variant="outline"
              onClick={isScanning ? stopScanning : startScanning}
              className="flex-1"
            >
              {isScanning ? (
                <>
                  <X className="mr-2 h-4 w-4" />
                  Stop
                </>
              ) : (
                <>
                  <RefreshCw className="mr-2 h-4 w-4" />
                  Retry
                </>
              )}
            </Button>
          </div>

          <div className="mt-4 text-center">
            <p className="text-xs text-white/60">
              Ensure QR code is well-lit and within the frame
            </p>
          </div>
        </div>
      </Card>
    </div>
  );
};

export default QRScanner;
