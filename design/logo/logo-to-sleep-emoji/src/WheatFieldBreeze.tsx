import {
  AbsoluteFill,
  CanvasImage,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const source = staticFile("wheat-wind-source.png");

type WheatLayerProps = {
  top: number;
  height: number;
  amplitude: number;
  rotation: number;
  phase: number;
};

const WheatLayer: React.FC<WheatLayerProps> = ({
  top,
  height,
  amplitude,
  rotation,
  phase,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const seconds = frame / fps;
  const sway =
    Math.sin((seconds / 4.8) * Math.PI * 2 + phase) * 0.72 +
    Math.sin((seconds / 2.9) * Math.PI * 2 + phase * 1.7) * 0.28;
  const translation = sway * amplitude;
  const turn = sway * rotation;

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: `${top}%`,
        width: "100%",
        height: `${height}%`,
        overflow: "hidden",
      }}
    >
      <CanvasImage
        src={source}
        style={{
          position: "absolute",
          left: 0,
          top: `${(-top / height) * 100}%`,
          width: "100%",
          height: `${(100 / height) * 100}%`,
          objectFit: "fill",
          translate: `${translation}px 0px`,
          rotate: `${turn}deg`,
          transformOrigin: "50% 100%",
          willChange: "transform",
        }}
      />
    </div>
  );
};

export const WheatFieldBreeze: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#1c140e", overflow: "hidden" }}>
      <CanvasImage
        src={source}
        style={{ width: "100%", height: "100%", objectFit: "cover" }}
      />

      <WheatLayer top={55} height={19} amplitude={2.5} rotation={0.12} phase={0.45} />
      <WheatLayer top={66} height={22} amplitude={5} rotation={0.28} phase={1.35} />
      <WheatLayer top={78} height={22} amplitude={9} rotation={0.52} phase={2.3} />
    </AbsoluteFill>
  );
};
