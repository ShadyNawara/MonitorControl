import Foundation

/// Custom error types for handling command execution and parsing failures.
enum LGTVClientError: Error {
  case commandFailed(String) // Thrown when a command-line execution fails
  case parsingFailed(String) // Thrown when output parsing fails
}

/// A class to interact with an LG TV using the `bscpylgtvcommand` command-line tool.
class LGTVClient {
  // MARK: - Private Helper Functions

  /// Executes a command-line command and returns its output.
  /// - Parameter command: The command string to execute.
  /// - Returns: The trimmed output string from the command.
  /// - Throws: `LGTVClientError` if execution or decoding fails.
  private static func runCommand(_ command: [String]) throws -> String {
    let process = Process()
    process.launchPath =
      "/Library/Frameworks/Python.framework/Versions/3.11/bin/bscpylgtvcommand"
    process.arguments =
      [
        "-p",
        URL(fileURLWithPath: NSHomeDirectory()).path + "/.aiopylgtv.sqlite",
      ] + command
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.launch()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
      throw LGTVClientError.parsingFailed("Failed to decode command output")
    }

    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if process.terminationStatus != 0 {
      throw LGTVClientError.commandFailed(trimmedOutput)
    }
    return trimmedOutput
  }

  /// Creates a JSON string from a dictionary.
  /// - Parameter dictionary: The dictionary to convert to JSON.
  /// - Returns: A JSON string representation.
  /// - Throws: `LGTVClientError` if JSON serialization fails.
  private static func jsonString(from dictionary: [String: Any]) throws
    -> String
  {
    let data = try JSONSerialization.data(
      withJSONObject: dictionary, options: []
    )
    guard let json = String(data: data, encoding: .utf8) else {
      throw LGTVClientError.parsingFailed("Failed to create JSON string")
    }
    return json
  }

  // MARK: - Brightness Control

  /// Sets the brightness of the TV.
  /// - Parameters:
  ///   - ip: The IP address of the TV.
  ///   - brightness: The brightness value to set.
  /// - Throws: `LGTVClientError` if the command fails.
  static func setBrightness(ip: String, brightness: Int) throws {
    let settings = ["backlight": brightness]
    let json = try jsonString(from: settings)
    let command = [ip, "set_current_picture_settings", json]
    let output = try runCommand(command)
    print(output)
  }

  /// Gets the current brightness of the TV.
  /// - Parameter ip: The IP address of the TV.
  /// - Returns: The current brightness value.
  /// - Throws: `LGTVClientError` if the command or parsing fails.
  static func getBrightness(ip: String) throws -> Int {
    let command = [ip, "get_picture_settings", "[\"backlight\"]", "true"]
    let output = try runCommand(command)
    // Step 1: Clean the output by removing newlines and normalizing escape characters
    let cleanedOutput =
      output
        .replacingOccurrences(of: "\n", with: "") // Remove newline characters
        .replacingOccurrences(of: "\\", with: "") // Remove extra escape characters (if unintended)
        .trimmingCharacters(in: .whitespacesAndNewlines) // Trim whitespace and newlines

    // Step 2: Convert the cleaned string to data for JSON parsing
    guard let data = cleanedOutput.data(using: .utf8) else {
      throw LGTVClientError.parsingFailed(
        "Failed to convert cleaned output to data: \(cleanedOutput)")
    }

    // Step 3: Parse the JSON and extract the backlight value
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: [])
        as? [String: Any],
        let backlightValue = json["backlight"]
      {
        // Handle different possible types for 'backlight'
        if let backlightStr = backlightValue as? String,
           let backlight = Int(backlightStr)
        {
          return backlight
        } else if let backlightInt = backlightValue as? Int {
          return backlightInt
        } else {
          throw LGTVClientError.parsingFailed(
            "Unexpected type for 'backlight': \(type(of: backlightValue)) in output: \(cleanedOutput)"
          )
        }
      } else {
        throw LGTVClientError.parsingFailed(
          "Failed to parse 'backlight' from output: \(cleanedOutput)")
      }
    } catch {
      throw LGTVClientError.parsingFailed(
        "JSON parsing error: \(error.localizedDescription), output: \(cleanedOutput)"
      )
    }
  }

  // MARK: - Volume Control

  /// Sets the volume of the TV.
  /// - Parameters:
  ///   - ip: The IP address of the TV.
  ///   - volume: The volume level to set.
  /// - Throws: `LGTVClientError` if the command fails.
  static func setVolume(ip: String, volume: Int) throws {
    let command = [ip, "set_volume", "\(volume)"]
    let output = try runCommand(command)
  }

  /// Gets the current volume of the TV.
  /// - Parameter ip: The IP address of the TV.
  /// - Returns: The current volume level.
  /// - Throws: `LGTVClientError` if the command or parsing fails.
  static func getVolume(ip: String) throws -> Int {
    let command = [ip, "get_volume"]
    let output = try runCommand(command)
    guard let volume = Int(output) else {
      throw LGTVClientError.parsingFailed("Failed to parse volume: \(output)")
    }
    return volume
  }
}
