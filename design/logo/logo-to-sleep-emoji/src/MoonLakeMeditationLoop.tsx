import {
  AbsoluteFill,
  CanvasImage,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const source = staticFile("moon-lake-source.jpg");
const totalFrames = 192;
const waterTop = 63.6;
const waterBands = 18;

type CropProps = {
  left: number;
  top: number;
  width: number;
  height: number;
  translateX?: number;
  translateY?: number;
  opacity?: number;
  filter?: string;
  maskImage?: string;
  mixBlendMode?: "normal" | "screen";
};

// The terminal frame deliberately reuses frame 0's values. This keeps the
// encoded last frame byte-for-byte compatible with the first loop state.
const loopPosition = (frame: number) =>
  frame === totalFrames - 1 ? 0 : frame / (totalFrames - 1);

// This reaches precisely 0 and 1 with zero velocity at both ends. The ripple
// travels towards the foreground, while frame 0 and frame 191 remain identical.
const travel = (position: number) =>
  position - Math.sin(position * Math.PI * 2) / (Math.PI * 2);

const SourceCrop: React.FC<CropProps> = ({
  left,
  top,
  width,
  height,
  translateX = 0,
  translateY = 0,
  opacity = 1,
  filter,
  maskImage,
  mixBlendMode = "normal",
}) => {
  const { width: canvasWidth, height: canvasHeight } = useVideoConfig();
  const cropLeft = (left / 100) * canvasWidth;
  const cropTop = (top / 100) * canvasHeight;

  return (
    <div
      style={{
        position: "absolute",
        left: cropLeft,
        top: cropTop,
        width: `${width}%`,
        height: `${height}%`,
        overflow: "hidden",
        opacity,
        filter,
        maskImage,
        WebkitMaskImage: maskImage,
        mixBlendMode,
        pointerEvents: "none",
      }}
    >
      <CanvasImage
        src={source}
        style={{
          position: "absolute",
          // Offset the complete source image back into the crop. The previous
          // value (0) sampled the wrong area whenever the crop was not at x=0.
          left: -cropLeft,
          top: -cropTop,
          width: canvasWidth,
          height: canvasHeight,
          translate: `${translateX}px ${translateY}px`,
        }}
      />
    </div>
  );
};

const WaterBand: React.FC<{ index: number }> = ({ index }) => {
  const frame = useCurrentFrame();
  const { height } = useVideoConfig();
  const position = loopPosition(frame);
  const phase = travel(position) * Math.PI * 2;
  const availableHeight = 100 - waterTop;
  const step = availableHeight / waterBands;
  const overlap = step * 0.38;
  const bandTop = waterTop + index * step - overlap;
  const bandHeight = step + overlap * 2;
  const depth = (index + 0.5) / waterBands;
  const wave =
    Math.sin(depth * 15.8 - phase) * 0.74 +
    Math.sin(depth * 37.2 - phase * 1.7 + 0.8) * 0.26;
  // 1–7px at delivery size: still low-amplitude, but legible in playback.
  const amplitude = 0.7 + Math.pow(depth, 1.25) * 6.0;
  const shimmer =
    1 +
    (Math.sin(depth * 19.4 - phase * 1.35 + 1.2) * 0.5 + 0.5) *
      (0.015 + depth * 0.04);

  return (
    <SourceCrop
      left={0}
      top={bandTop}
      width={100}
      height={bandHeight}
      translateX={wave * amplitude}
      translateY={Math.sin(depth * 12.1 - phase * 1.15) * amplitude * 0.16}
      filter={`brightness(${shimmer})`}
      maskImage="linear-gradient(to bottom, transparent 0%, rgba(0, 0, 0, 0.9) 20%, black 35%, black 65%, rgba(0, 0, 0, 0.9) 80%, transparent 100%)"
    />
  );
};

const WaterRipples: React.FC = () => {
  return (
    <>
      {Array.from({ length: waterBands }, (_, index) => (
        <WaterBand key={index} index={index} />
      ))}
    </>
  );
};

const LanternAndReflection: React.FC = () => {
  const frame = useCurrentFrame();
  const position = loopPosition(frame);
  const phase = position * Math.PI * 2;
  const lanternBreath =
    Math.sin(phase - 0.7) * 0.65 + Math.sin(phase * 2 + 1.1) * 0.35;
  const reflectionPulse = Math.sin(phase * 1.15 + 0.9) * 0.5 + 0.5;
  const farLightPulse = Math.sin(phase + 0.35) * 0.5 + 0.5;

  return (
    <>
      <SourceCrop
        left={17.7}
        top={66.2}
        width={8.2}
        height={7.7}
        opacity={0.73 + lanternBreath * 0.22}
        filter="brightness(1.24) saturate(1.1)"
        maskImage="radial-gradient(ellipse at 48% 47%, black 0%, rgba(0, 0, 0, 0.95) 27%, rgba(0, 0, 0, 0.48) 49%, transparent 73%)"
      />
      <SourceCrop
        left={18.3}
        top={72.2}
        width={6.3}
        height={8.1}
        opacity={0.23 + lanternBreath * 0.07}
        filter="brightness(1.3) saturate(1.1)"
        maskImage="radial-gradient(ellipse at 50% 35%, black 0%, rgba(0, 0, 0, 0.8) 34%, transparent 77%)"
        mixBlendMode="screen"
      />
      <SourceCrop
        left={49.5}
        top={73.0}
        width={24.0}
        height={19.0}
        opacity={0.09 + reflectionPulse * 0.13}
        filter="brightness(1.58) blur(0.2px)"
        maskImage="radial-gradient(ellipse at 50% 50%, black 4%, rgba(0, 0, 0, 0.82) 38%, rgba(0, 0, 0, 0.22) 67%, transparent 92%)"
        mixBlendMode="screen"
      />
      <SourceCrop
        left={4}
        top={62.2}
        width={92}
        height={4.0}
        opacity={0.22 + farLightPulse * 0.09}
        filter="brightness(1.075)"
        maskImage="linear-gradient(to bottom, transparent 0%, rgba(0, 0, 0, 0.8) 30%, black 52%, rgba(0, 0, 0, 0.75) 76%, transparent 100%)"
        mixBlendMode="screen"
      />
    </>
  );
};

const VegetationBreath: React.FC = () => {
  const frame = useCurrentFrame();
  const position = loopPosition(frame);
  const phase = position * Math.PI * 2;
  const treeShift =
    Math.sin(phase + 0.15) * 0.36 + Math.sin(phase * 2 - 0.9) * 0.08;
  const reedShift =
    Math.sin(phase - 0.55) * 0.76 + Math.sin(phase * 2.1 + 0.35) * 0.16;

  return (
    <>
      <SourceCrop
        left={0}
        top={7}
        width={59}
        height={55}
        translateX={treeShift}
        opacity={0.96}
        maskImage="radial-gradient(ellipse at 14% 51%, black 5%, rgba(0, 0, 0, 0.96) 47%, rgba(0, 0, 0, 0.48) 68%, transparent 91%)"
      />
      <SourceCrop
        left={0}
        top={64}
        width={42}
        height={36}
        translateX={reedShift}
        opacity={0.94}
        maskImage="radial-gradient(ellipse at 14% 74%, black 3%, rgba(0, 0, 0, 0.94) 46%, rgba(0, 0, 0, 0.42) 71%, transparent 96%)"
      />
    </>
  );
};

export const MoonLakeMeditationLoop: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#07152d", overflow: "hidden" }}>
      <CanvasImage
        src={source}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
      />
      <WaterRipples />
      <VegetationBreath />
      <LanternAndReflection />
    </AbsoluteFill>
  );
};
