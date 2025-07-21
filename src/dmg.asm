INCLUDE "../external/hardware.inc/hardware.inc"
INCLUDE "constants.inc"
INCLUDE "header.inc"

SECTION "Boot ROM", ROM0[$0000]

EntryPoint:
    ld sp, hStackBottom

    xor a
    ld hl, _VRAM + SIZEOF(VRAM) - 1
.clearVRAM
    ld [hld], a
    bit 7, h
    jr nz, .clearVRAM

    ld hl, rNR52
    ld c, LOW(rNR11) ; CH1 length
    ; Enable APU
    ; This sets (roughly) all audio registers to 0
    ld a, AUDENA_ON
    ld [hld], a
    ASSERT rNR52 - 1 == rNR51
    ; Set CH1 duty cycle to 25%
    ASSERT AUDENA_ON == AUDLEN_DUTY_50
    ldh [c], a
    inc c
    ASSERT LOW(rNR11) + 1 == LOW(rNR12)
    ; Set CH1 envelope
    ld a, (15 << 4) | AUDENV_DOWN | 3 ; Initial volume 15, decreasing sweep 3
    ldh [c], a
    ; Route all channels to left speaker, CH2 and CH1 to right speaker
    ; Note that only channel 1 will be used!
    ld [hld], a
    ASSERT rNR51 - 1 == rNR50
    ; Set volume on both speakers to max, disable VIN on both speakers
    ld a, $77
    ld [hl], a

    ld a, %11_11_11_00
    ldh [rBGP], a

    ld de, HeaderLogo
    ld hl, vLogoTiles
.decompressLogo
    ld a, [de]
    call DecompressFirstNibble
    call DecompressSecondNibble
    inc de
    ld a, e
    cp LOW(HeaderTitle)
    jr nz, .decompressLogo

    ; ld hl, vRTile
    ld de, RTile
    ld b, 8
.copyRTile
    ld a, [de]
    inc de
    ld [hli], a
    inc hl ; Skip every other byte
    dec b
    jr nz, .copyRTile
    ld a, $19
    ld [vMainTilemap + SCRN_VX_B * 8 + 16], a ; 8 rows down, 16 across

    ld hl, vMainTilemap + SCRN_VX_B * 9 + 15
.writeTilemapRow
    ld c, 12
.writeTilemapByte
    dec a
    jr z, ScrollLogo
    ld [hld], a
    dec c
    jr nz, .writeTilemapByte
    ld l, LOW(vMainTilemap + SCRN_VX_B * 8 + 15)
    jr .writeTilemapRow

ScrollLogo:
    ; a = 0
    ld h, a ; ld h, 0
    ld a, 100
    ld d, a
    ldh [rSCY], a
    ld a, LCDCF_ON | LCDCF_BLK01 | LCDCF_BGON
    ldh [rLCDC], a
    inc b ; ld b, 1

    ; h = Number of times the logo was scrolled up
    ; d = How many frames before exiting the loop
    ; b = Whether to scroll the logo

.loop
    ld e, 2
.delayFrames
    ld c, 12
.waitVBlank
    ldh a, [rLY]
    cp SCRN_Y
    jr nz, .waitVBlank
    dec c
    jr nz, .waitVBlank
    dec e
    jr nz, .delayFrames

    ld c, LOW(rNR13) ; CH1 frequency low byte
    inc h
    ld a, h
    ld e, $83
    cp $62
    jr z, .playSound
    ld e, $C1
    cp $64
    jr nz, .dontPlaySound
.playSound
    ld a, e
    ldh [c], a
    inc c ; ld c, LOW(rNR14) ; CH1 frequency high byte
    ; Set frequency to $7XX and restart channel
    ld a, AUDHIGH_RESTART | 7
    ldh [c], a
.dontPlaySound
    ldh a, [rSCY]
    sub b
    ldh [rSCY], a
    dec d
    jr nz, .loop

    dec b
    jr nz, BootDone
    ld d, 32
    jr .loop

DecompressFirstNibble:
    ld c, a
DecompressSecondNibble:
    ld b, 8 / 2 ; Set all 8 bits of a, "consuming" 4 bits of c
.loop
    push bc
    rl c ; Extract MSB of c
    rla ; Into LSB of a
    pop bc
    rl c ; Extract that same bit
    rla ; So that bit is inserted twice in a (= horizontally doubled)
    dec b
    jr nz, .loop
    ld [hli], a
    inc hl ; Skip second plane
    ld [hli], a ; Also double vertically
    inc hl
    ret

RTile:
    PUSHO
    OPT b.X
    db %..XXXX..
    db %.X....X.
    db %X.XXX..X
    db %X.X..X.X
    db %X.XXX..X
    db %X.X..X.X
    db %.X....X.
    db %..XXXX..
    POPO

BootDone:
    ld  a, BOOTUP_A_DMG
    ldh [rBANK], a
    jp  $0100
    ds $0100 - @, 0 ; Fill to $0100
    ASSERT @ == $100

SECTION "VRAM tiles", VRAM[_VRAM], BANK[0]

vBlankTile:
    ds TILE_SIZE
vLogoTiles:
    ds (HeaderTitle - HeaderLogo) * TILE_SIZE / 2
vRTile:
    ds TILE_SIZE

SECTION "VRAM tilemap", VRAM[_SCRN0], BANK[0]

vMainTilemap:
    ds SCRN_VX_B * SCRN_VY_B

SECTION "HRAM", HRAM[$FFEE]

    ds $10
hStackBottom:
