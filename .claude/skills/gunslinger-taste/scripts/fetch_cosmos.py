"""Pull a public Cosmos collection into a folder so the images can be looked at.

Cosmos renders its grid in JavaScript, so a plain page fetch returns no items.
The element list is embedded in the page's Next.js payload; this reads it out.

    python -I fetch_cosmos.py https://www.cosmos.so/lvkelvke/western <out_dir>

Writes <out_dir>/elements.json (source URL, credit, caption, media URLs),
<out_dir>/img/NN_k.jpg (560px copies) and, when Pillow is installed,
<out_dir>/sheet_N.jpg contact sheets of six images each, labelled NN_k.
Only the first page of the collection is embedded (about 30 items).
"""
import glob
import json
import os
import re
import sys
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126 Safari/537.36"}
CELL = 480


def get(url: str) -> bytes:
	return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30).read()


def elements(html: str) -> list[dict]:
	# The payload is JSON inside a JS string, so quotes arrive backslash-escaped.
	text = html.replace('\\\\"', "\x00").replace('\\"', '"').replace("\x00", '\\"')
	decoder = json.JSONDecoder()
	found, seen = [], set()
	for match in re.finditer(r'\{"__typename":"[A-Za-z]*ElementTile"', text):
		try:
			tile, _ = decoder.raw_decode(text, match.start())
		except ValueError:
			continue
		if tile["id"] in seen:
			continue
		seen.add(tile["id"])
		source = tile.get("source") or {}
		author = source.get("author") or {}
		caption = tile.get("generatedCaption") or {}
		media = [m["url"] for m in tile.get("multipleMedia") or []]
		if not media and tile.get("media"):
			media = [tile["media"]["url"]]
		found.append({
			"id": tile["id"],
			"share_url": tile.get("shareUrl"),
			"source_url": source.get("url"),
			"credit": author.get("fullName") or author.get("username"),
			"page_title": tile.get("websiteTitle"),
			"caption": re.sub(r"</?n>", "", caption.get("text") or ""),
			"media": media,
		})
	return found


def contact_sheets(out_dir: str) -> int:
	try:
		from PIL import Image, ImageDraw
	except ImportError:
		return 0
	files = sorted(glob.glob(os.path.join(out_dir, "img", "*.jpg")))
	for start in range(0, len(files), 6):
		sheet = Image.new("RGB", (CELL * 3, CELL * 2), "white")
		for k, path in enumerate(files[start:start + 6]):
			image = Image.open(path).convert("RGB")
			image.thumbnail((CELL - 8, CELL - 8))
			col, row = k % 3, k // 3
			sheet.paste(image, (col * CELL + (CELL - image.width) // 2, row * CELL + (CELL - image.height) // 2))
			ImageDraw.Draw(sheet).text((col * CELL + 6, row * CELL + 4), os.path.basename(path)[:4], fill="red")
		sheet.save(os.path.join(out_dir, f"sheet_{start // 6}.jpg"), quality=85)
	return (len(files) + 5) // 6


def main() -> int:
	if len(sys.argv) != 3:
		print(__doc__)
		return 2
	url, out_dir = sys.argv[1], sys.argv[2]
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")
	os.makedirs(os.path.join(out_dir, "img"), exist_ok=True)
	found = elements(get(url).decode("utf-8", errors="replace"))
	with open(os.path.join(out_dir, "elements.json"), "w", encoding="utf-8") as handle:
		json.dump(found, handle, indent=1, ensure_ascii=False)
	for index, item in enumerate(found):
		print(f"{index:02d} | {item['source_url']} | {item['credit']} | {item['caption'] or item['page_title'] or ''}")
		for k, media_url in enumerate(item["media"][:2]):
			path = os.path.join(out_dir, "img", f"{index:02d}_{k}.jpg")
			if os.path.exists(path):
				continue
			try:
				with open(path, "wb") as handle:
					handle.write(get(media_url + "?format=jpeg&w=560"))
			except OSError as error:
				print(f"   failed {media_url}: {error}")
	print(f"{len(found)} elements, {contact_sheets(out_dir)} contact sheets in {out_dir}")
	return 0 if found else 1


if __name__ == "__main__":
	sys.exit(main())
