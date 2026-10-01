import subprocess
import time
import os

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(base_dir, 'backend')
    dashboard_dir = os.path.join(base_dir, 'dashboard')
    
    print("Starting backend...")
    backend_process = subprocess.Popen(
        r".\.venv\Scripts\uvicorn.exe app.main:app --reload --host 127.0.0.1 --port 8000", 
        cwd=backend_dir, 
        shell=True
    )
    
    print("Starting dashboard...")
    dashboard_process = subprocess.Popen(
        "npm run dev", 
        cwd=dashboard_dir, 
        shell=True
    )
    
    print("Both processes are running. Press Ctrl+C to stop.")
    
    try:
        while True:
            time.sleep(1)
            if backend_process.poll() is not None:
                print("Backend process exited unexpectedly.")
                break
            if dashboard_process.poll() is not None:
                print("Dashboard process exited unexpectedly.")
                break
    except KeyboardInterrupt:
        print("\nStopping processes...")
    finally:
        print("Terminating process trees...")
        # Using taskkill to kill the process tree on Windows
        subprocess.call(['taskkill', '/F', '/T', '/PID', str(backend_process.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.call(['taskkill', '/F', '/T', '/PID', str(dashboard_process.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Done.")

if __name__ == "__main__":
    main()
