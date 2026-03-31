#!/usr/bin/env python3
"""Import and rename source images into assets/original/.

Copy files from the Brass: Birmingham source image directory into
assets/original/ with human-readable names.

Usage: python scripts/import_assets.py
"""

import os
import shutil

# ---------------------------------------------------------------------------
# Source -> destination filename mapping
# ---------------------------------------------------------------------------

FILE_MAP = {
    # Board
    "httpssteamusercontentaakamaihdnetugc216572860965317704425817700C7529A9657879940356D6E405A8D2DF1.jpg": "board.jpg",

    # Card sheets
    "httpssteamusercontentaakamaihdnetugc21657286096531745750E0587829BF940706A3160EBEA5D9C11E512D805.jpg": "cards_face_6x6.jpg",
    "httpssteamusercontentaakamaihdnetugc2188247245679406117E9CD95F3F60A03C9E5AA3D64980223601DE4032F.jpg": "cards_face_4x8.jpg",
    "httpssteamusercontentaakamaihdnetugc2188247245679406828525F74C1593BA710AE408CEC85475DFF9C4E0ABC.jpg": "cards_back_4x8.jpg",
    "httpssteamusercontentaakamaihdnetugc987863257461228308C0D0FF1693A1F219F9DC3A8DB86B77EAE81712C4.jpg": "card_back_single.jpg",

    # Player aids
    "httpssteamusercontentaakamaihdnetugc2165728609653173001BB0D630F58B87EACCD2C11D60594B6AE9F7C02A0.jpg": "player_aid_flow_zh.jpg",
    "httpssteamusercontentaakamaihdnetugc216572860965317371849D6FA3BD82AE451E208B217A8BA96D07E68083E.jpg": "player_aid_cards_zh.jpg",
    "httpmqpiccnpsbV11KbKJY3WF7aeDxShnlGKEn2JGSbPTfBlNPVXclr313ogBFkIt1EPaobdFMBAAAAAAAAbogAJaBjoDMwgRCeIrfviewer4.jpg": "player_aid_actions_zh.jpg",

    # Tile sheets (front faces per player color)
    "httpssteamusercontentaakamaihdnetugc987863257460567094CA13E07E6BDA1D54A13D6A1ECF51CF97DA8274BF.jpg": "tiles_front_purple.jpg",
    "httpssteamusercontentaakamaihdnetugc98786325746056767035AF4950AD7FFCBB6B0A7D218479A6F973565A1A.jpg": "tiles_front_grey.jpg",
    "httpssteamusercontentaakamaihdnetugc98786325746056911059EF30BD1439C1D8BEFDA8B9F12C55737ACFAFFB.jpg": "tiles_front_orange.jpg",
    "httpssteamusercontentaakamaihdnetugc987863257460569681AD8E8F3CE520FBCCAEB5E34866665F92C4C812E2.jpg": "tiles_front_yellow.jpg",

    # Tile sheet (backs)
    "httpssteamusercontentaakamaihdnetugc970984067088078265C95C1F18A9C023CF94514C5529424F4341EF5F38.jpg": "tiles_back_all.jpg",

    # Player boards
    "httpssteamusercontentaakamaihdnetugc970984067088082589B3025B9E696DC4F1836387323787349F6CCB30B9.jpg": "player_board_purple.jpg",
    "httpssteamusercontentaakamaihdnetugc970984067088083184F762DED5739F7E2342BD360914A99F33C1D756B5.jpg": "player_board_grey.jpg",
    "httpssteamusercontentaakamaihdnetugc97098406708808414207A38E5F19253940B65F9CC6BAD401B515C8AEFD.jpg": "player_board_orange.jpg",
    "httpssteamusercontentaakamaihdnetugc9709840670880845349BE428A0E6C3435C60867D9C6709919FD05E5462.jpg": "player_board_yellow.jpg",

    # Merchant tiles (8 portraits)
    "httpssteamusercontentaakamaihdnetugc18166147348818094339201AF6238228FFBAA3D3C9724749D262BCFC5DF.png": "merchant_red_1.png",
    "httpssteamusercontentaakamaihdnetugc18166147348818103397274369F1B6F52C9702880649E4935A14A085E48.png": "merchant_red_2.png",
    "httpssteamusercontentaakamaihdnetugc1816614734881813871ED38ED8DF91EC55B9CE4440DE67B52458D8E80DB.png": "merchant_purple_1.png",
    "httpssteamusercontentaakamaihdnetugc18166147348818148631CE52794F1223B094CF95554F775BA750926A7B1.png": "merchant_purple_2.png",
    "httpssteamusercontentaakamaihdnetugc18166147348818159165763E97572AED6F045D96D36DD8CF7B14DADB057.png": "merchant_blue_1.png",
    "httpssteamusercontentaakamaihdnetugc1816614734881817322FDB5E5650284FB9464384E979C3ACF6C2EDB064D.png": "merchant_blue_2.png",
    "httpssteamusercontentaakamaihdnetugc181661473488181855546ECCD1BF1B9B19A8789EF0F0C1A5FEF4D6B767D.png": "merchant_gold_1.png",
    "httpssteamusercontentaakamaihdnetugc1816614734881818977714C5AF249BA118087E3D65C5244ACE586A26A15.png": "merchant_gold_2.png",

    # Link tiles
    "httpssteamusercontentaakamaihdnetugc20091985920315691182E559286F55EC094241CEB9CAC2BAEA760C2553D.jpg": "link_purple_rail.jpg",
    "httpssteamusercontentaakamaihdnetugc2009198592031571374628ED4FCAD34FE324DB45F471DB1214611D530E6.jpg": "link_purple_canal.jpg",
    "httpssteamusercontentaakamaihdnetugc2009198592031590736E074A3EB8BF273B61D8F83B3506286152E427F07.jpg": "link_orange_rail.jpg",
    "httpssteamusercontentaakamaihdnetugc20091985920315916614F313AAD5CE2463311909AD03D44F2674CD3BC7B.jpg": "link_orange_canal.jpg",
    "httpssteamusercontentaakamaihdnetugc20091985920315926767F362422FCEDB3D7CA5E12E88E1466642F1F2A2D.jpg": "link_white_canal.jpg",
    "httpssteamusercontentaakamaihdnetugc200919859203159338465307CD170C805D7F1F9F25F8B58F00990400E81.jpg": "link_white_rail.jpg",
    "httpssteamusercontentaakamaihdnetugc2009198592031594123C55EEF4F6F4DC665A0851B50BFC70C1CDE564C31.jpg": "link_yellow_canal.jpg",
    "httpssteamusercontentaakamaihdnetugc200919859203159484593428099F4D8BB8331C1091368AF150259F0351F.jpg": "link_yellow_rail.jpg",

    # Wild tiles
    "httpssteamusercontentaakamaihdnetugc9878632574608394792CF61FBBB2A79F4A48861340C4A847FE9353250F.jpg": "wild_industry_sheet.jpg",
    "httpssteamusercontentaakamaihdnetugc987863257460840171A36EF817659328A2AF568F3B1375AB0C3A72ACC6.jpg": "wild_location_back.jpg",

    # 3D textures
    "httpssteamusercontentaakamaihdnetugc2009198592028039882D7532857A29A7433532A558CE8CF9B5321CA0936.jpg": "texture_barrel.jpg",
    "httpssteamusercontentaakamaihdnetugc2009198592028077463C518D80E31E27DB23EEAC8CF9253E59798865790.jpg": "texture_building.jpg",
    "httpssteamusercontentaakamaihdnetugc2009198592028115280FDE6AA64575F7CA00503D877E257D94800AA66BE.jpg": "texture_machinery.jpg",
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SOURCE_DIR = r"C:\Users\andyc\Downloads\Brass Birmingham images"
DEST_DIR = os.path.join(PROJECT_ROOT, "assets", "original")


def main() -> None:
    os.makedirs(DEST_DIR, exist_ok=True)

    copied = 0
    missing = 0
    skipped = 0

    for src_name, dest_name in FILE_MAP.items():
        src_path = os.path.join(SOURCE_DIR, src_name)
        dest_path = os.path.join(DEST_DIR, dest_name)

        if not os.path.exists(src_path):
            print(f"  MISSING  {src_name}")
            missing += 1
            continue

        if os.path.exists(dest_path):
            # Overwrite unconditionally so the mapping is always fresh
            pass

        shutil.copy2(src_path, dest_path)
        print(f"  OK  {src_name}  ->  {dest_name}")
        copied += 1

    print()
    print(f"Done: {copied} copied, {skipped} skipped, {missing} missing")
    print(f"Output directory: {DEST_DIR}")


if __name__ == "__main__":
    main()
