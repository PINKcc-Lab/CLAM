import os
import shutil

import docker

DATA_DIR = "/Users/chad/Documents/data/EXTRACTION_SN"

client = docker.from_env()


def run_segmentation_in_docker(source_dir, save_dir, models_dir, config_path):
    try:
        container = client.containers.run(
            "clam-ovaire",
            command="bash ./seg.sh",
            volumes={
                source_dir: {"bind": "/data", "mode": "rw"},
                save_dir: {"bind": "/results", "mode": "rw"},
                models_dir: {"bind": "/models", "mode": "rw"},
            },
            detach=True,
        )
        for line in container.logs(stream=True):
            print(line.decode("utf-8").strip())
        container.wait()
    except docker.errors.ContainerError as e:
        print(f"Container error: {e.stderr.decode('utf-8')}")
    except Exception as e:
        print(f"Error running Docker container: {str(e)}")


if __name__ == "__main__":
    for root, dirs, files in os.walk(DATA_DIR):
        for dir in dirs:
            if dir.endswith("histo"):
                print(f"Found histology directory: {dir}")

                source_dir = os.path.join(root, dir)
                save_dir = "/Users/chad/Documents/dev/PY/CLAM/results"
                models_dir = "/Users/chad/Documents/dev/PY/CLAM/models"
                config_path = "/Users/chad/Documents/dev/PY/CLAM/config.yaml"

                # Clean the save directory before running segmentation
                if os.path.exists(save_dir):
                    shutil.rmtree(save_dir)
                os.makedirs(save_dir, exist_ok=True)

                print(f"Running segmentation for {source_dir}...")
                run_segmentation_in_docker(
                    source_dir, save_dir, models_dir, config_path
                )

                print(
                    f"Segmentation completed for {source_dir}."
                )
