import "./index.css";
import { Composition } from "remotion";
import { LogoToSleepEmoji } from "./Composition";
import { WheatFieldBreeze } from "./WheatFieldBreeze";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="LogoToSleepEmoji"
        component={LogoToSleepEmoji}
        durationInFrames={120}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="WheatFieldBreeze"
        component={WheatFieldBreeze}
        durationInFrames={240}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
