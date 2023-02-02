# MacBook Optimization Script

This shell script is designed to optimize a MacBook with an Intel processor. The script includes a series of commands that disable certain features, enable others, and make changes to settings to improve performance.

## Installation
Open your Mac's Terminal to run the script.

```bash
sudo sh ./script.sh
```

## Usage

1. Download the shell script and save it to your MacBook.
2. Open the terminal and navigate to the directory where the script is saved.
3. Make the script executable with the following command: 
```chmod +x <script_name>.sh```
4. Run the script with the following command: 
```./<script_name>.sh```

## Content 

The script includes the following optimizations:

1. Disables spotlight indexing
2. Disables sleep image to save disk space
3. Disables App Nap
4. Disables automatic termination of inactive apps
5. Enables continuous disk checking
6. Enables TRIM
7. Enables lid wake
8. Optimizes swap usage
9. Disables the sudden motion sensor
10. Disables hibernation and sleep
11. Flushes the DNS cache
12. Optimizes spotlight for faster searches

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)
