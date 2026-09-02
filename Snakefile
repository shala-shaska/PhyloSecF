import os
from snakemake.exceptions import WorkflowError

configfile: "config.yaml"

# config.get() próbuje pobrać ścieżkę nadaną przez usera, a jeśli jej nie ma - bierze "input"
# glob_wildcards skanuje dysk i zwraca listę tego, co znalazł w miejscu {sample}
# domyslnie .fasta, ale furtka ext z workflowerror w razie jak user jest deiblem i ma w folderze rozne pliki albo jeszcze jakies nukleotydowe (do zrobienia)
INPUT_DIR = config.get("input_dir", "input")
EXT = config.get("ext", "fasta")
SAMPLES, = glob_wildcards(os.path.join(INPUT_DIR, "{sample}." + EXT))
print(f"Scanning folder: '{INPUT_DIR}' for: *.{EXT} files")
if not SAMPLES:
    # WorkflowError fajny błąd Snakemake'a, zatrzymuje po naszemu bez trashtalku pythona
    raise WorkflowError(
        f"\n[!] CRITICAL ERROR: No *.{EXT} files found in input folder!\n"
        f"Ensure correct PROTEIN SEQUENCE INPUT folder.\n"
        f"If your files have other extension e.g. (.fa or .faa), "
        f"use flag:\n"
        f"snakemake --config ext=YOUR_EXTENSION\n"
    )
else:
    print(f"[OK] Found {len(SAMPLES)} files for analysis.\n")

# --- REGUŁA KOŃCOWA (CEL) ---
rule all:
    input:
        "output/orthofinder/Orthogroups/Orthogroups.tsv"

# --- REGUŁY WYKONAWCZE ---

rule run_orthofinder:
    input:
        # expand() mnoży naszą listę SAMPLES. Podajemy to tutaj po to, 
        # by Snakemake "obserwował" te pliki. Jeśli za miesiąc dorzucisz
        # nowy plik .fa, Snakemake zauważy zmianę w wejściu i odpali regułę na nowo.
        expand(os.path.join(INPUT_DIR, "{sample}.fa"), sample=SAMPLES)
    output:
        # Zgodnie z tym, co wpisaliśmy w rule all
        "output/orthofinder/Orthogroups/Orthogroups.tsv"
    conda:
        "envs/orthofinder.yml"
    params:
        # params to miejsce na zmienne, które nie są plikami wejściowymi
        in_dir = INPUT_DIR,
        out_dir = "output/orthofinder"
    threads:
        # Pobieramy wartość z pliku config.yaml
        config["threads"]
    shell:
        """
        # 1. Uruchamiamy OrthoFinder, kierując go do folderu z '_tmp' na końcu
        orthofinder -f {params.in_dir} -t {threads} -a {threads} -o {params.out_dir}_tmp
        
        # 2. Program utworzył folder typu 'output/orthofinder_tmp/Results_Jun26/'
        # Tworzymy nasz właściwy folder i przenosimy tam zawartość
        mkdir -p {params.out_dir}
        mv {params.out_dir}_tmp/Results_*/* {params.out_dir}/
        
        # 3. Usuwamy śmieci
        rm -rf {params.out_dir}_tmp
        """
