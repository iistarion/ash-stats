# Ash Stats

This repository contains the `stats.sh` script, designed to provide essential system statistics.

## Features

- Displays system uptime.
- Shows memory and disk usage.
- Outputs CPU load and network statistics.

## Usage

1. Clone the repository:
    ```bash
    git clone <repository-url>
    cd ash-stats
    ```

2. Make the script executable:
    ```bash
    chmod +x stats.sh
    ```

3. Run the script:
    ```bash
    ./stats.sh
    ```

## Docker Usage

A prebuilt Docker image is available on Docker Hub: [cyaque/ash-stats](https://hub.docker.com/r/cyaque/ash-stats).

1. Run the container:
    ```bash
    docker run --rm  cyaque/ash-stats
    ```

2. Alternatively, use the `run.sh` script for advanced options like host network monitoring, JSON output, and periodic updates:
    ```bash
    ./run.sh
    ```

## Requirements

- Bash shell
- Standard Linux/Unix utilities (e.g., `df`, `nproc`, `iostat`)
- Docker (optional, for containerized usage)

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Contributing

Feel free to fork this repository and submit pull requests to enhance its functionality or add new features. By contributing, you agree that your contributions will be licensed under the same [GNU General Public License v3.0](LICENSE) as this project. Please note that simplicity is a key priority for this project.

## Author

Ash Stats is maintained by Carlos Yaque.