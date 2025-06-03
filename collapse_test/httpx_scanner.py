import subprocess
from collections import defaultdict

INPUT_FILE = "sites_to_scan.txt"  
OUTPUT_PREFIX = "test"            
STATS_FILE = "stats.txt"         
SCAN_TIMES = 10              

def run_httpx(scan_id):
    output_file = f"{OUTPUT_PREFIX}{scan_id}.txt"
    command = f"httpx -l {INPUT_FILE} -status-code -silent -o {output_file}"
    try:
        subprocess.run(command, shell=True, check=True, text=True)
        print(f"[+] Запуск {scan_id}: {command}")
    except subprocess.CalledProcessError as e:
        print(f"[-] Ошибка в запуске {scan_id}: {e}")

def analyze_results():
    found_stats = defaultdict(int)

    for scan_id in range(1, SCAN_TIMES + 1):
        run_httpx(scan_id)
        
        output_file = f"{OUTPUT_PREFIX}{scan_id}.txt"
        try:
            with open(output_file, "r") as f:
                for line in f:
                    url = line.strip()
                    if url:
                        found_stats[url] += 1
        except FileNotFoundError:
            print(f"[-] Файл {output_file} не найден!")
    
    with open(STATS_FILE, "w") as f:
        f.write("Статистика обнаруженных сайтов:\n")
        for url, count in sorted(found_stats.items(), key=lambda x: x[1], reverse=True):
            f.write(f"{url} — {count}/{SCAN_TIMES} раз\n")
    
    print(f"\n[+] Все сканирования завершены. Статистика в {STATS_FILE}")

if __name__ == "__main__":
    analyze_results()