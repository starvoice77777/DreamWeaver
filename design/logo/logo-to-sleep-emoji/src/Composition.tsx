import {
  AbsoluteFill,
  CanvasImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};

export const LogoToSleepEmoji: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill
      name="Black background"
      style={{
        backgroundColor: "#000000",
        overflow: "hidden",
      }}
    >
      <Interactive.Div
        name="Top z motion"
        style={{
          position: "absolute",
          left: interpolate(frame, [0, 24, 82], [363.5, 363.5, 620], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          top: interpolate(frame, [0, 24, 82], [230.8, 230.8, 335], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          width: 311.8,
          height: 204,
          scale: interpolate(frame, [0, 24, 82], [1, 1.012, 0.5], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
            output: "perceptual-scale",
          }),
          rotate: interpolate(frame, [24, 82], ["0deg", "-4deg"], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          opacity: interpolate(frame, [80, 94], [1, 0], {
            ...clamp,
            easing: Easing.bezier(0.4, 0, 1, 1),
          }),
          filter: `blur(${interpolate(frame, [82, 96], [0, 5], {
            ...clamp,
          })}px)`,
          transformOrigin: "center",
        }}
      >
        <CanvasImage
          name="Top z beige"
          src={staticFile("z-top-beige.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [54, 80], [1, 0], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
        <CanvasImage
          name="Top z blue"
          src={staticFile("z-top-blue.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [54, 80], [0, 1], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
      </Interactive.Div>

      <Interactive.Div
        name="Middle z motion"
        style={{
          position: "absolute",
          left: interpolate(frame, [0, 31, 86], [345.3, 345.3, 500], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          top: interpolate(frame, [0, 31, 86], [435.8, 435.8, 460], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          width: 210.1,
          height: 233.4,
          scale: interpolate(frame, [0, 31, 86], [1, 1.012, 0.6], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
            output: "perceptual-scale",
          }),
          rotate: interpolate(frame, [31, 86], ["0deg", "-2deg"], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          opacity: interpolate(frame, [82, 96], [1, 0], {
            ...clamp,
            easing: Easing.bezier(0.4, 0, 1, 1),
          }),
          filter: `blur(${interpolate(frame, [84, 98], [0, 5], {
            ...clamp,
          })}px)`,
          transformOrigin: "center",
        }}
      >
        <CanvasImage
          name="Middle z beige"
          src={staticFile("z-middle-beige.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [58, 82], [1, 0], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
        <CanvasImage
          name="Middle z blue"
          src={staticFile("z-middle-blue.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [58, 82], [0, 1], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
      </Interactive.Div>

      <Interactive.Div
        name="Bottom z motion"
        style={{
          position: "absolute",
          left: interpolate(frame, [0, 38, 90], [392.7, 392.7, 345], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          top: interpolate(frame, [0, 38, 90], [635.6, 635.6, 590], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          width: 342.7,
          height: 204,
          scale: interpolate(frame, [0, 38, 90], [1, 1.012, 0.62], {
            ...clamp,
            easing: [Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
            output: "perceptual-scale",
          }),
          rotate: interpolate(frame, [38, 90], ["0deg", "2deg"], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          opacity: interpolate(frame, [84, 98], [1, 0], {
            ...clamp,
            easing: Easing.bezier(0.4, 0, 1, 1),
          }),
          filter: `blur(${interpolate(frame, [88, 102], [0, 5], {
            ...clamp,
          })}px)`,
          transformOrigin: "center",
        }}
      >
        <CanvasImage
          name="Bottom z beige"
          src={staticFile("z-bottom-beige.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [62, 86], [1, 0], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
        <CanvasImage
          name="Bottom z blue"
          src={staticFile("z-bottom-blue.png")}
          style={{
            position: "absolute",
            inset: 0,
            width: "100%",
            height: "100%",
            opacity: interpolate(frame, [62, 86], [0, 1], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
      </Interactive.Div>

      <Interactive.Div
        name="Sleep emoji"
        style={{
          position: "absolute",
          left: 290,
          top: 285,
          width: 500,
          height: 500,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: '"Apple Color Emoji", "Noto Color Emoji", sans-serif',
          fontSize: 370,
          lineHeight: 1,
          opacity: interpolate(frame, [84, 100], [0, 1], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [78, 94, 106], [0.72, 1.055, 1], {
            ...clamp,
            easing: [
              Easing.bezier(0.16, 1, 0.3, 1),
              Easing.bezier(0.34, 1.56, 0.64, 1),
            ],
            output: "perceptual-scale",
          }),
          translate: interpolate(frame, [78, 104], ["-12px 18px", "0px 0px"], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        💤
      </Interactive.Div>
    </AbsoluteFill>
  );
};
