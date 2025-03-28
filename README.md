# Ash Stats

This repository contains a script `stats.sh` designed to provide various system statistics.

## Features

- Displays system uptime.
- Shows memory usage.
- Lists disk usage.
- Outputs CPU load.
- Provides network statistics.

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

You can also run the script using Docker:

1. Build the Docker image:
    ```bash
    docker build -t ash-stats .
    ```

2. Run the container:
    ```bash
    docker run --rm ash-stats
    ```

## Requirements

- Bash shell
- Basic Linux/Unix utilities (e.g., `uptime`, `df`, `free`, `top`, etc.)

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Contributing

Feel free to fork this repository and submit pull requests to enhance its functionality or add new features. By contributing, you agree that your contributions will be licensed under the same [GNU General Public License v3.0](LICENSE) as this project. Please note that simplicity is a key priority for this project though!

## Author

Ash Stats is maintained by Carlos Yaque.