# PetFPVwidget_HU – pixelart kisállat widget 

Teljes képernyős (320x240) widget: pixelart macska vagy kutya, amely hangulatokat mutat, reagál a telemetriára (LQ, RSSI, vevő- és adóakku), és jelzi az ARM állapotot.

## Telepítés

1. Másold az `SD/WIDGETS/PetFPV/` mappát az SD-kártyára, így: `SD:/WIDGETS/PetFPV/main.lua` és `SD:/WIDGETS/PetFPV/img/...`
2. Válassz 1 zónás (teljes képernyős) elrendezést, és add hozzá a widgetet.

A mappa neve maradjon `PetFPV`: az EdgeTX a widget mappanevét legfeljebb 8 karakterre engedi, és a kód is ezt az útvonalat használja.

## Fajták (`Fajta` opció, 1–10)

| # | Fajta |
|---|-------|
| 1 | Sziámi (kék jegyű) |
| 2 | Háromszínű (calico) |
| 3 | Fekete macska |
| 4 | Brit rövidszőrű |
| 5 | Vörös cirmos |
| 6 | Golden retriever |
| 7 | Husky |
| 8 | Harlekin tacskó |
| 9 | Corgi |
| 10 | Németjuhász |

## Működés

- Nyugodt állapotban 4 másodpercenként vált a hangulat: nyugodt, boldog, nézelődő, izgatott, unatkozó, álmos. A kutyák boldogan lihegnek.
- Nincs telemetria: az állat alszik.
- Rossz értéknél az állat sír, a keret pirosan villog, feliratot kap, és hangjelzés szólal meg:
  - LQ < 70 % (`LQLow` opció)
  - RSSI < -95 dBm (`RssiLow` opció)
  - Vevőakku < 3,50 V cellánként (`CELL_LOW` konstans)
  - Adóakku < 6,8 V (`TX_LOW_V` konstans)
- ARM jelzés jobb felül: zöld SAFE / villogó piros ARMED, elszánt arccal; ARM/DISARM váltáskor hang is szól.
- Az alsó állapotsor az LQ, RSSI, RX és TX értékét mutatja zöld / piros / szürke jelzéssel.

## Widget opciók (az EdgeTX legfeljebb 5-öt enged)

| Opció | Alapérték | Jelentés |
|-------|-----------|----------|
| LQLow | 70 | LQ figyelmeztetési határ (%) |
| RssiLow | -95 | RSSI figyelmeztetési határ (dBm) |
| Cells | 0 | Vevőakku cellaszáma, 0 = automatikus |
| ArmSw | ch5 | ARM kapcsoló vagy csatorna |
| Fajta | 1 | Fajta, 1–10 |

A `main.lua` elején állítható konstansok: `ARM_ACTIVE_HIGH` (true: felső állás = ARM), `TX_LOW_V`, `CELL_LOW`, `CARD` (háttérkártya), `DEBUG`.

## Tudnivalók

- A feliratokban nincs ékezet (az EdgeTX betűtípusa miatt).
- Az automatikus cellaszám-felismerés részlegesen töltött akkunál tévedhet; ilyenkor add meg a `Cells` értékét.


## Köszönetnyilvánítás
Külön köszönet **haverr44**-nek a scriptben használt pixel art grafikákért.