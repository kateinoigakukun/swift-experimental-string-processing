import _StringProcessing
import Foundation

public protocol RegexBenchmark {
  var name: String { get }
  func run()
}

public struct Benchmark: RegexBenchmark {
  public let name: String
  let regex: Regex<Substring>
  let ty: MatchType
  let target: String

  public enum MatchType {
    case whole
    case first
    case allMatches
  }
  
  public func run() {
    switch ty {
    case .whole: blackHole(target.wholeMatch(of: regex))
    case .allMatches: blackHole(target.matches(of: regex))
    case .first: blackHole(target.firstMatch(of: regex))
    }
  }
}

public struct NSBenchmark: RegexBenchmark {
  public let name: String
  let regex: NSRegularExpression
  let ty: NSMatchType
  let target: String
  
  var range: NSRange {
    NSRange(target.startIndex..<target.endIndex, in: target)
  }

  public enum NSMatchType {
    case all
    case first
  }
  
  public func run() {
    switch ty {
    case .all: blackHole(regex.matches(in: target, range: range))
    case .first: blackHole(regex.firstMatch(in: target, range: range))
    }
  }
}

public struct BenchmarkRunner {
  // Register instances of Benchmark and run them
  let suiteName: String
  var suite: [any RegexBenchmark]
  let samples: Int
  
  public init(_ suiteName: String) {
    self.suiteName = suiteName
    self.suite = []
    self.samples = 20
  }
  
  public init(_ suiteName: String, _ n: Int) {
    self.suiteName = suiteName
    self.suite = []
    self.samples = n
  }

  public mutating func register(_ new: some RegexBenchmark) {
    suite.append(new)
  }
  
  func measure(benchmark: some RegexBenchmark) -> Time {
    var times: [Time] = []
    
    // initial run to make sure the regex has been compiled
    benchmark.run()
    
    // fixme: use suspendingclock?
    for _ in 0..<samples {
      let start = Tick.now
      benchmark.run()
      let end = Tick.now
      let time = end.elapsedTime(since: start)
      times.append(time)
    }
    // todo: compute stdev and warn if it's too large
    
    // return median time
    times.sort()
    return times[samples/2]
  }
  
  public func run() {
    print("Running")
    for b in suite {
      print("- \(b.name) \(measure(benchmark: b))")
    }
  }
  
  public func profile() {
    print("Starting")
    for b in suite {
      print("- \(b.name)")
      b.run()
      print("- done")
    }
  }
}

// nom nom nom, consume the argument
@inline(never)
public func blackHole<T>(_ x: T) {
}
