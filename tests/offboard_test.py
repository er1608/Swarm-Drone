import os
import sys
import time
import signal
import subprocess
import threading
import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PX4OffboardTest:
    def __init__(self):
        self.px4_process = None
        self.offboard_process = None
        self.test_passed = False
        
        self.px4_binary = "./build/px4_sitl_default/bin/px4"
        self.sitl_script = "./Tools/sitl_run.sh"
        self.offboard_app = "./your_offboard_app"
        self.model = "iris"
        self.world = "none"
        self.simulator = "gazebo"

        self.latitude = "47.397742"
        self.longitude = "8.545594"
        self.altitude = "488"

        self.mavlink_url = "udp://:14540"
        
    def start_px4(self):
        logger.info("Starting PX4 SITL with Gazebo...")

        env = os.environ.copy()
        env.update({
            'PX4_HOME_LAT': self.latitude,
            'PX4_HOME_LON': self.longitude,
            'PX4_HOME_ALT': self.altitude,
        })
        
        cmd = [
            self.sitl_script,
            self.px4_binary,
            self.model,
            self.world,
            self.simulator,
            self.latitude,
            self.longitude,
            self.altitude
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        
        try:
            self.px4_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                preexec_fn=os.setsid  # Create process group
            )
            
            # Start thread to capture logs
            threading.Thread(
                target=self._capture_output,
                args=(self.px4_process, "PX4"),
                daemon=True
            ).start()
            
            logger.info(f"PX4 process started with PID: {self.px4_process.pid}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start PX4: {e}")
            return False
    
    def _capture_output(self, process, name):
        """Capture and log output from a process"""
        try:
            for line in process.stdout:
                logger.debug(f"[{name}] {line.strip()}")
        except Exception as e:
            logger.debug(f"Error capturing {name} output: {e}")
    
    def wait_for_px4_ready(self, timeout=60):
        """Wait for PX4 to be ready"""
        logger.info(f"Waiting for PX4 to be ready (timeout: {timeout}s)...")
        
        start_time = time.time()
        check_interval = 2
        
        while time.time() - start_time < timeout:
            
            # Check for specific log patterns indicating PX4 is ready
            # You might want to check for MAVLink connection readiness
            logger.info(f"Waiting... ({int(time.time() - start_time)}s)")
            time.sleep(check_interval)
            
            # Additional check: see if Gazebo is running
            try:
                gz_process = subprocess.run(
                    ["pgrep", "-f", "gzserver"],
                    capture_output=True,
                    text=True
                )
                if gz_process.returncode == 0:
                    logger.info("Gazebo is running!")
            except:
                pass
        
        logger.info("PX4 should be ready now")
        return True
    
    def run_offboard_test(self, timeout=120):
        """Run the offboard control test"""
        logger.info("Starting offboard control test...")

        cmd = [self.offboard_app, "--url", self.mavlink_url]
        
        logger.info(f"Running offboard command: {' '.join(cmd)}")
        
        try:
            self.offboard_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            threading.Thread(
                target=self._capture_output,
                args=(self.offboard_process, "OFFBOARD"),
                daemon=True
            ).start()

            logger.info(f"Waiting for offboard test to complete (timeout: {timeout}s)...")
            
            try:
                return_code = self.offboard_process.wait(timeout=timeout)
                
                if return_code == 0:
                    logger.info("Offboard test PASSED!")
                    self.test_passed = True
                else:
                    logger.error(f"Offboard test FAILED with return code: {return_code}")
                    self.test_passed = False
                
                return self.test_passed
                
            except subprocess.TimeoutExpired:
                logger.error(f"Offboard test TIMED OUT after {timeout}s")
                return False
                
        except Exception as e:
            logger.error(f"Failed to run offboard test: {e}")
            return False
    
    def validate_test_results(self):
        """Validate test results - customize this based on your needs"""
        logger.info("Validating test results...")
        
        validation_passed = True

        expected_files = [
            "logs/offboard_log.csv",
            "logs/flight_path.png",
        ]
        
        for file in expected_files:
            if Path(file).exists():
                logger.info(f"✓ Found expected file: {file}")
            else:
                logger.warning(f"✗ Missing expected file: {file}")
                validation_passed = False
        
        # Check for error patterns in logs
        error_patterns = ["ERROR", "FAILED", "Exception", "Crash"]
        
        try:
            with open("logs/offboard_log.txt", "r") as f:
                log_content = f.read()
                for pattern in error_patterns:
                    if pattern in log_content:
                        logger.warning(f"Found error pattern in log: {pattern}")
        except:
            pass
        
        return validation_passed
    
    def cleanup(self):
        """Cleanup processes"""
        logger.info("Cleaning up...")
        
        if self.offboard_process and self.offboard_process.poll() is None:
            logger.info("Terminating offboard process...")
            self.offboard_process.terminate()
            try:
                self.offboard_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.offboard_process.kill()
        
        if self.px4_process and self.px4_process.poll() is None:
            logger.info("Terminating PX4 process...")

            os.killpg(os.getpgid(self.px4_process.pid), signal.SIGTERM)
            try:
                self.px4_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(self.px4_process.pid), signal.SIGKILL)
        
        subprocess.run(["pkill", "-f", "gzserver"], capture_output=True)
        subprocess.run(["pkill", "-f", "gazebo"], capture_output=True)
        
        logger.info("Cleanup completed")
    
    def run(self):
        """Main test runner"""
        try:
            if not self.start_px4():
                return False
            
            if not self.wait_for_px4_ready(timeout=30):
                self.cleanup()
                return False
            
            test_result = self.run_offboard_test(timeout=60)
            
            validation_result = self.validate_test_results()
            
            final_result = test_result and validation_result
            
            if final_result:
                logger.info("=" * 50)
                logger.info("🎉 ALL TESTS PASSED!")
                logger.info("=" * 50)
            else:
                logger.error("=" * 50)
                logger.error("💥 TESTS FAILED!")
                logger.error("=" * 50)
            
            return final_result
            
        except KeyboardInterrupt:
            logger.info("Test interrupted by user")
            return False
        except Exception as e:
            logger.error(f"Unexpected error: {e}", exc_info=True)
            return False
        finally:
            self.cleanup()

def main():
    
    test_runner = PX4OffboardTest()
    
    import argparse
    parser = argparse.ArgumentParser(description="PX4 Offboard Control Test")
    parser.add_argument("--offboard-app", help="Path to offboard application")
    parser.add_argument("--model", default="iris", help="PX4 model")
    parser.add_argument("--timeout", type=int, default=60, help="Test timeout in seconds")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.offboard_app:
        test_runner.offboard_app = args.offboard_app
    if args.model:
        test_runner.model = args.model
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    success = test_runner.run()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()