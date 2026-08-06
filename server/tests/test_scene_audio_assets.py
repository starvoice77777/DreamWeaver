import hashlib
import wave
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIO_ROOT = REPO_ROOT / "DreamWeaver" / "Resources" / "Audio"

LATEST_PRESET_AUDIO_SHA256 = {
    "rain_soft.wav": "215297a7ee333c798421525efa851b7cc31475ba9188aa0ab1bbf0bab6bb604c",
    "rain_parasol.wav": "a361d85288237ccb5f8c2afc58e4f441addf571320fb9c8a9087a8878ff6bc80",
    "rain_bamboo_leaf.wav": "503817d66bd8961a037c410cf755cc9dc900560739ff18f39e1a2ce8149492b5",
    "wind_gust.wav": "a51557c87d9f2003b395a9bb77fe517502836653e649189bb29b9632b5093535",
    "hair_wash_water_cycle.wav": "87f715fe3f97aba98f0605c4b629dac8c6d6eb0d014ab837105333214050b571",
    "hair_wash_wet.wav": "8caa38a193a9a0bdc489ce44a4cb484a4bdc6c1b6e31f11b1768fd24ac6b00ff",
    "hair_wash_foam_start.wav": "67de99afd6eff50e584c6060447187296a2a2b1e8d4c7fc4e94e4fcadae4553a",
    "hair_wash_foam_rub.wav": "5fd1ffb5703f15a1f889266bcaae8bf2a32fd07ad6604d4839e4fdcd94cb8cc9",
    "hair_wash_scalp_foam.wav": "179c76a99977c5ae30bba87bbc939606bf08fddb30d67e520d5374468d3e2cd8",
    "hair_wash_rinse.wav": "1db3f8334da20ea71f771f730df10fcd500e4c68251fd2edb4dd870e9a1b5907",
    "hair_wash_finger_massage.wav": (
        "2157e2ccfa222b5b79c12364e195a07eb7ea5ff66cd9910e36f90ea52466d6c6"
    ),
    "hair_towel.wav": "b189a498174ae5b99c272d84197e2c36ded6837099191fbdd262b2a084f0afc4",
    "water_drip_roomtone.wav": "1e5f51b0083577176780d410170c5611bf18442e2e82098a9c43aaa679fc6ed1",
    "voice_phrase_01.wav": "218a72e86f867a271b9a09859e9cb12e0d9d5b4e362ea20c574bcb873135c185",
    "voice_phrase_02.wav": "61f7425396faa7b512ef71dfff2b82503f254fb92a1fe0e14a602064a488ab97",
    "voice_phrase_03.wav": "c0e521f94a1782cf45cfc975313076f9ca1317bc985e4fa9e216a9283507d17f",
    "voice_phrase_04.wav": "f0cb640c2f3d21b59207913e08159a80d111257e08411b6c9be051bad8c3660d",
    "voice_phrase_05.wav": "5c55d84bc7f9b400eda1b2aa432efc0cdd2105048305264e5d37433f8bd285c7",
    "voice_phrase_06.wav": "5e98307c7676f8f8773bdea26882e6b6f6d71e4d9e5d681b61af6776556d4d49",
    "voice_phrase_07.wav": "d2277ddc407fe43c16f864877627ab0a157ae6cce91ded888b10a1d1269cae36",
    "voice_phrase_08.wav": "eedfdc009c7aeab229e6dabafc07673ac1a0d9ccc308ea803e03a331e760853a",
    "voice_phrase_09.wav": "be215cc699a92f1c702488e1a218b1bfe096478cc1206c663973fe9e7e0ced9c",
    "voice_phrase_10.wav": "c7330b74852acd232a598845314a466e9031baa6d669e2afa3f78270158e250d",
    "voice_phrase_11.wav": "9f58e3d3393455a1a1572e33917f0839c5206283bd6681904907d17347ad84d3",
    "voice_phrase_12.wav": "188847c1e594e5cc314a5cf2e1f05128d89fca1b7f8bb9a57d09559be48fb4c1",
    "voice_phrase_13.wav": "6ff481afa958330d667f5f14544e89c52f3b01736434e11099f664feed5ae34e",
    "voice_phrase_14.wav": "4ef3af9c617e7abb057fedb5dc9b5c2744441311d48351edb6b04ba2bee8a1dc",
    "voice_phrase_15.wav": "9b1a6906f391b2dc4aa0aadd271418168388d2fac050c4dd3166daf9cd1104f1",
    "voice_phrase_16.wav": "806159d14347e81ae628bfad5512c5ce48b9b869acab9fa930467419b87b381b",
    "voice_phrase_17.wav": "22d4d5d0a470b797927c65f21c345c9ac2cf2483ff0e40294a9cbd4d22209307",
    "voice_phrase_18.wav": "39815fe632e4c5d1015493862a38f5b8d79d26f28cc91b0114efec5514b86a6d",
    "voice_phrase_19.wav": "c5904e98dc7bf833c8c06addb4a6bd204cc498893cd5384726a9d9f214610155",
    "voice_phrase_20.wav": "5dc4ff667183229f0fb6037f09b16e2d60715c951dfef426a648e8f471aba372",
}

OBSOLETE_PRESET_AUDIO = {
    "hair_dryer.mp3",
    "hair_wash.m4a",
    "hair_wash_care_spray.wav",
    "hair_wash_care_tool.wav",
    "hair_wash_scalp_massage.wav",
    "rain_parasol.m4a",
    "rain_soft.mp3",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def test_latest_preset_audio_matches_delivered_masters() -> None:
    actual = {
        name: _sha256(AUDIO_ROOT / name)
        for name in LATEST_PRESET_AUDIO_SHA256
    }
    assert actual == LATEST_PRESET_AUDIO_SHA256


def test_obsolete_preset_audio_is_not_bundled() -> None:
    remaining = {name for name in OBSOLETE_PRESET_AUDIO if (AUDIO_ROOT / name).exists()}
    assert remaining == set()


def test_latest_preset_audio_is_playable_non_silent_pcm() -> None:
    for name in LATEST_PRESET_AUDIO_SHA256:
        with wave.open(str(AUDIO_ROOT / name), "rb") as audio:
            assert audio.getframerate() == 48_000
            assert audio.getnchannels() == 2
            expected_sample_width = 3 if name == "wind_gust.wav" else 2
            assert audio.getsampwidth() == expected_sample_width
            assert any(audio.readframes(audio.getnframes()))
