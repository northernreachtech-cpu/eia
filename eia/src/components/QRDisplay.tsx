import { useEffect, useRef } from 'react';
import QRCode from 'qrcode';
import { Download, Share2 } from 'lucide-react';
import Button from './Button';
import Card from './Card';

interface QRDisplayProps {
  data: string;
  title?: string;
  subtitle?: string;
  size?: number;
  onClose?: () => void;
  showActions?: boolean;
}

const QRDisplay = ({ 
  data, 
  title = "QR Code", 
  subtitle, 
  size = 256, 
  onClose,
  showActions = true 
}: QRDisplayProps) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (canvasRef.current) {
      QRCode.toCanvas(
        canvasRef.current,
        data,
        {
          width: size,
          margin: 2,
          color: {
            dark: '#000000',
            light: '#FFFFFF',
          },
        },
        (error) => {
          if (error) console.error('QR Code generation error:', error);
        }
      );
    }
  }, [data, size]);

  const downloadQR = () => {
    if (canvasRef.current) {
      const link = document.createElement('a');
      link.download = 'qr-code.png';
      link.href = canvasRef.current.toDataURL();
      link.click();
    }
  };

  const shareQR = async () => {
    if (navigator.share && canvasRef.current) {
      try {
        const canvas = canvasRef.current;
        canvas.toBlob(async (blob) => {
          if (blob) {
            const file = new File([blob], 'qr-code.png', { type: 'image/png' });
            await navigator.share({
              title: title,
              text: subtitle || 'Check out this QR code',
              files: [file],
            });
          }
        });
      } catch (error) {
        console.error('Error sharing QR code:', error);
        // Fallback to download
        downloadQR();
      }
    } else {
      // Fallback to download if Web Share API is not supported
      downloadQR();
    }
  };

  return (
    <Card className="p-6 text-center max-w-sm mx-auto">
      <h3 className="text-xl font-semibold mb-2">{title}</h3>
      {subtitle && (
        <p className="text-white/70 text-sm mb-6">{subtitle}</p>
      )}
      
      <div className="mb-6 flex justify-center">
        <div className="bg-white p-4 rounded-lg">
          <canvas 
            ref={canvasRef}
            className="block"
          />
        </div>
      </div>

      <div className="text-xs text-white/60 mb-4">
        Scan this code with your mobile device
      </div>

      {showActions && (
        <div className="flex gap-2 justify-center">
          <Button 
            variant="outline" 
            size="sm" 
            onClick={downloadQR}
            className="flex-1"
          >
            <Download className="mr-2 h-4 w-4" />
            Download
          </Button>
          
          <Button 
            variant="outline" 
            size="sm" 
            onClick={shareQR}
            className="flex-1"
          >
            <Share2 className="mr-2 h-4 w-4" />
            Share
          </Button>
          
          {onClose && (
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={onClose}
              className="flex-1"
            >
              Close
            </Button>
          )}
        </div>
      )}
    </Card>
  );
};

export default QRDisplay; 