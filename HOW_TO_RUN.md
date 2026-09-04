# Godot / Nevidar

## Запуск

1. Открой Godot 4.7
2. Import → папка `arpg_Nevidar`
3. Play (F5)

Или из консоли:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\eilukhin\Documents\Ai_agent\arpg_Nevidar"
```

## Управление

- WASD — движение
- ЛКМ — удар | Q — сплеш | E — удар по земле (ур.4)
- Пробел — рывок
- **I / Tab** — инвентарь (сетка + экип + тултип)
- В инвентаре: ПКМ экип/снять, ЛКМ выбрать, клик по клетке — перенос, кнопка «Опознать»
- F1–F8 — пассивки
- R — рестарт


## Структура

- `scenes/` — арена, игрок, враг
- `scripts/combat/` — статы и формула урона
- `scripts/player/` — воин
- `scripts/enemy/` — 4 типа врагов
- `base/` — замороженные доки, не трогать
