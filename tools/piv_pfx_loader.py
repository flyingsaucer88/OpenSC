#!/usr/bin/env python3
"""
Load a PKCS#12/PFX certificate into all PIV slots (9A, 9C, 9D, 9E).
Requires OpenSSL and piv-tool (from OpenSC) to be available.
"""

import argparse
import datetime as dt
import os
import shutil
import subprocess
import sys
import tempfile


SLOTS = ["9A", "9C", "9D", "9E"]


def desktop_log_path(prefix: str = "piv_pfx_load") -> str:
    desktop = os.path.join(os.path.expanduser("~"), "Desktop")
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{prefix}_{timestamp}.log"
    return os.path.join(desktop, filename)


def setup_log(log_path: str):
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    log_file = open(log_path, "a", encoding="utf-8")
    return log_file


def log_line(log_file, message: str):
    ts = dt.datetime.now().isoformat(timespec="seconds")
    log_file.write(f"{ts} {message}\n")
    log_file.flush()


def run_cmd(cmd, log_file, label: str):
    log_line(log_file, f"RUN {label}: {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except OSError as exc:
        log_line(log_file, f"ERROR {label}: {exc}")
        raise
    if result.stdout:
        log_line(log_file, f"STDOUT {label}: {result.stdout.strip()}")
    if result.stderr:
        log_line(log_file, f"STDERR {label}: {result.stderr.strip()}")
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")
    return result


def extract_cert_from_pfx(openssl_path, pfx_path, pfx_password, out_pem, log_file):
    pass_arg = f"pass:{pfx_password}"
    cmd = [
        openssl_path,
        "pkcs12",
        "-in",
        pfx_path,
        "-clcerts",
        "-nokeys",
        "-out",
        out_pem,
        "-passin",
        pass_arg,
    ]
    run_cmd(cmd, log_file, "extract_cert")


def load_cert_into_slot(piv_tool_path, slot, cert_pem, reader, admin_mode, log_file):
    cmd = [piv_tool_path, "--cert", slot, "--in", cert_pem]
    if reader:
        cmd.extend(["-r", reader])
    if admin_mode:
        cmd.extend(["-A", admin_mode])
    run_cmd(cmd, log_file, f"load_slot_{slot}")


def print_cert_attributes(openssl_path, cert_pem):
    cmd = [
        openssl_path,
        "x509",
        "-in",
        cert_pem,
        "-noout",
        "-subject",
        "-issuer",
        "-serial",
        "-dates",
        "-fingerprint",
        "-ext",
        "subjectAltName",
        "-ext",
        "keyUsage",
        "-ext",
        "extendedKeyUsage",
    ]
    result = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        sys.stderr.write("Failed to read certificate attributes with openssl.\n")
        sys.stderr.write(result.stderr)
        return 1
    print("Certificate attributes:")
    print(result.stdout.strip())
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Load a .pfx certificate into all PIV slots (9A, 9C, 9D, 9E)."
    )
    parser.add_argument("--pfx", required=True, help="Path to the .pfx/.p12 file.")
    parser.add_argument("--pfx-password", required=True, help="Password for the .pfx file.")
    parser.add_argument(
        "--piv-tool",
        default="piv-tool",
        help="Path to piv-tool binary (default: piv-tool in PATH).",
    )
    parser.add_argument(
        "--openssl",
        default="openssl",
        help="Path to openssl binary (default: openssl in PATH).",
    )
    parser.add_argument(
        "--reader",
        default=None,
        help="Optional smart card reader name to pass to piv-tool.",
    )
    parser.add_argument(
        "--admin",
        default=None,
        help="Optional admin mode string for piv-tool, e.g. A:9B:11 or M:9B:11.",
    )

    args = parser.parse_args()

    log_path = desktop_log_path()
    log_file = setup_log(log_path)
    log_line(log_file, "Starting PFX load process")
    log_line(log_file, f"Log file: {log_path}")
    log_line(log_file, f"PFX path: {args.pfx}")
    log_line(log_file, f"PIV tool: {args.piv_tool}")
    log_line(log_file, f"OpenSSL: {args.openssl}")

    if not os.path.isfile(args.pfx):
        log_line(log_file, "ERROR: PFX file does not exist")
        sys.stderr.write(f"PFX file not found: {args.pfx}\n")
        sys.stderr.write(f"Log file: {log_path}\n")
        return 2

    piv_tool_path = shutil.which(args.piv_tool) or args.piv_tool
    openssl_path = shutil.which(args.openssl) or args.openssl
    if not os.path.isfile(piv_tool_path) and shutil.which(args.piv_tool) is None:
        log_line(log_file, "ERROR: piv-tool not found")
        sys.stderr.write("piv-tool not found. Provide --piv-tool with a valid path.\n")
        sys.stderr.write(f"Log file: {log_path}\n")
        return 2
    if not os.path.isfile(openssl_path) and shutil.which(args.openssl) is None:
        log_line(log_file, "ERROR: openssl not found")
        sys.stderr.write("openssl not found. Provide --openssl with a valid path.\n")
        sys.stderr.write(f"Log file: {log_path}\n")
        return 2

    try:
        with tempfile.TemporaryDirectory(prefix="piv_pfx_") as tmpdir:
            cert_pem = os.path.join(tmpdir, "cert.pem")
            extract_cert_from_pfx(openssl_path, args.pfx, args.pfx_password, cert_pem, log_file)
            for slot in SLOTS:
                log_line(log_file, f"Loading certificate into slot {slot}")
                load_cert_into_slot(
                    piv_tool_path, slot, cert_pem, args.reader, args.admin, log_file
                )
            log_line(log_file, "All slots loaded successfully")
            print(f"Certificate loaded into slots {', '.join(SLOTS)}.")
            print(f"Log file: {log_path}")
            return print_cert_attributes(openssl_path, cert_pem)
    except Exception as exc:
        log_line(log_file, f"ERROR: {exc}")
        sys.stderr.write(f"Failed to load certificate: {exc}\n")
        sys.stderr.write(f"Log file: {log_path}\n")
        return 1
    finally:
        log_file.close()


if __name__ == "__main__":
    sys.exit(main())
