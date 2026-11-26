"""Repair coder and Wand defects in specific historical source archives."""

from pathlib import Path
import re
import sys


def replace(contents, before, after, count=1):
    if contents.count(before) != count:
        raise ValueError(f"Expected {count} occurrence(s) of {before!r}")
    return contents.replace(before, after)


def fix_png_palette(contents):
    # Quantize byte channels, then convert back to the configured Quantum.
    # This also scales the mask to the right depth for HDRI.
    helper = b"""static inline Quantum PNG8QuantizeChannel(const Quantum quantum,
  const unsigned char mask)
{
  const unsigned char sample=ScaleQuantumToChar(quantum) & mask;
  if (mask == 0xe0)
    return(ScaleCharToQuantum(sample | (sample >> 3) | (sample >> 6)));
  return(ScaleCharToQuantum(sample | (sample >> 2) | (sample >> 4) |
    (sample >> 6)));
}

"""
    anchor = b"static inline ssize_t MagickMax"
    contents = replace(contents, anchor, helper + anchor)
    for pixel in (b"image->background_color.", b"r->", b"image->colormap[i]."):
        pattern = (
            rb"^( +)if \(image->depth == 8\)\n +\{\n +" + re.escape(pixel)
            + rb"red=.*?^#endif\n"
        )
        match, = list(re.finditer(pattern, contents, re.MULTILINE | re.DOTALL))
        indent = match.group(1)
        lines = []
        for channel, mask in ((b"red", b"0xe0"), (b"green", b"0xe0"), (b"blue", b"0xc0")):
            field = pixel + channel
            lines.append(indent + field + b"=PNG8QuantizeChannel(" + field + b"," + mask + b");\n")
        contents = contents[:match.start()] + b"".join(lines) + contents[match.end():]
    return contents


def fix_dicom_bytes(contents):
    # Combine the byte planes in the integer domain before converting to Quantum.
    for channel in (b"red", b"green", b"blue"):
        field = b"q->" + channel
        sample = b"pixel." + channel
        contents = replace(
            contents, field + b"|=((Quantum) " + sample + b") << 8;",
            field + b"=(Quantum) (((size_t) " + field + b") | (" + sample + b" << 8));",
        )
    return contents


def fix_wand_cache_arguments(contents):
    # Backport 6.7.7's Image arguments to the Wand OpenMP cache queries.
    contents = replace(
        contents, b"dynamic_number_threads(source,width,height,1)",
        b"dynamic_number_threads(source_image,width,height,1)", count=4,
    )
    return replace(
        contents, b"dynamic_number_threads(destination,width,height,1)",
        b"dynamic_number_threads(destination_image,width,height,1)",
    )


def fix_openjpeg_stream_api(contents):
    # Backport 6.8.9's OpenJPEG 2.1 stream API usage. The stream borrows Image.
    contents = replace(
        contents, b"opj_stream_set_user_data(jp2_stream,image);",
        b"opj_stream_set_user_data(jp2_stream,image,NULL);", count=2,
    )
    contents = replace(
        contents, b"opj_stream_destroy_v3(jp2_stream);",
        b"opj_stream_destroy(jp2_stream);", count=6,
    )
    contents, removed = re.subn(
        rb"^ +opj_stream_set_user_data\(jp2_stream,NULL\);\n", b"", contents, flags=re.MULTILINE,
    )
    if removed != 7:
        raise ValueError(f"Expected seven old OpenJPEG stream resets, found {removed}")
    return contents


def fix_openjpeg_ping(contents):
    return replace(
        contents, b"(jp2_image->comps[i].data == NULL))",
        b"((image->ping == MagickFalse) && (jp2_image->comps[i].data == NULL)))",
    )


def fix_svg_compliance(contents):
    # A valid compliance token must exit the draw parser's switch case.
    line = b"              MagickComplianceOptions,MagickFalse,token);\n"
    return replace(contents, line + b"          }", line + b"            break;\n          }")


def fix_bmp_row_stride(contents):
    # Backport 6.9.13's calculation of the full padded raster row.
    return replace(
        contents, b"bytes_per_line=image->columns*(4*(bmp_info.bits_per_pixel+31)/32);",
        b"bytes_per_line=4*((image->columns*bmp_info.bits_per_pixel+31)/32);",
    )


def fix_webp_progress_context(contents):
    # WebPMux uses custom_ptr for its writer. Upstream 7.0.7-16 gives the
    # progress callback its own Image pointer without altering the writer.
    progress = b"  status=SetImageProgress(image,EncodeImageTag,percent-1,100);"
    contents = replace(
        contents, b"  image=(Image *) picture->custom_ptr;\n" + progress,
        b"  image=(Image *) picture->user_data;\n" + progress,
    )
    hook = b"  picture.progress_hook=WebPEncodeProgress;\n"
    return replace(contents, hook, hook + b"  picture.user_data=(void *) image;\n")


def fix_magic_priority(contents):
    # Backport 7.0.8-14's ordering so the WEBP signature at offset 8
    # takes precedence over the generic RIFF signature at offset 0.
    return replace(
        contents,
        b"  if (ma->offset != mb->offset)\n"
        b"    return((int) (ma->offset-mb->offset));\n",
        b"  if (ma->offset != mb->offset)\n"
        b"    {\n"
        b"      MagickOffsetType\n"
        b"        max_offset;\n\n"
        b"      max_offset=ma->offset > mb->offset ? ma->offset : mb->offset;\n"
        b"      if (max_offset <= 10)\n"
        b"        return((int) (mb->offset-ma->offset));\n"
        b"      return((int) (ma->offset-mb->offset));\n"
        b"    }\n",
    )


FIXES = {
    "png-palette": fix_png_palette,
    "dicom-bytes": fix_dicom_bytes,
    "wand-cache-arguments": fix_wand_cache_arguments,
    "openjpeg-stream-api": fix_openjpeg_stream_api,
    "openjpeg-ping": fix_openjpeg_ping,
    "svg-compliance": fix_svg_compliance,
    "bmp-row-stride": fix_bmp_row_stride,
    "webp-progress-context": fix_webp_progress_context,
    "magic-priority": fix_magic_priority,
}


if __name__ == "__main__":
    _, repair, name = sys.argv
    path = Path(name)
    path.write_bytes(FIXES[repair](path.read_bytes()))
