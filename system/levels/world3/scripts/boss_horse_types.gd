class_name BossHorseTypes
extends RefCounted

## 四马身份（与 `boss_horse_minor` 的 `horse_id` 一致）
enum HorseId {
	GREY = 0,
	WHITE = 1,
	BLACK = 2,
	RED = 3,
}

## Boss 阶段占位；具体状态机实现时在此扩展（参见 Docs/11）
enum BossPhase {
	INTRO,
	SI_TO_FOUR_VISUAL,
	FOUR_EXIT_GREY_ENTER,
	GREY_SOLO,
	WHITE_SOLO,
	BLACK_SOLO,
	RED_SOLO,
	FINAL_WARNING_20,
	CHAIN_CINEMATIC,
	ALL_HORSES,
}


static func phase_to_text(phase: BossPhase) -> String:
	match phase:
		BossPhase.INTRO:
			return "INTRO"
		BossPhase.SI_TO_FOUR_VISUAL:
			return "SI_TO_FOUR_VISUAL"
		BossPhase.FOUR_EXIT_GREY_ENTER:
			return "FOUR_EXIT_GREY_ENTER"
		BossPhase.GREY_SOLO:
			return "GREY_SOLO"
		BossPhase.WHITE_SOLO:
			return "WHITE_SOLO"
		BossPhase.BLACK_SOLO:
			return "BLACK_SOLO"
		BossPhase.RED_SOLO:
			return "RED_SOLO"
		BossPhase.FINAL_WARNING_20:
			return "FINAL_WARNING_20"
		BossPhase.CHAIN_CINEMATIC:
			return "CHAIN_CINEMATIC"
		BossPhase.ALL_HORSES:
			return "ALL_HORSES"
		_:
			return "UNKNOWN"
