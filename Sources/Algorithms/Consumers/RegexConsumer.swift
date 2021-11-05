import Regex

public struct Regex {
  let string: String
  let options: REOptions
  
  init(_ string: String, options: REOptions = .none) {
    self.string = string
    self.options = options
  }
}

public struct RegexConsumer: CollectionConsumer {
  // NOTE: existential
  let vm: VirtualMachine
  let referenceVM: VirtualMachine

  public init(regex: Regex) {
    let code = try! compile(regex.string, options: regex.options)
    self.vm = HareVM(code)
    self.referenceVM = TortoiseVM(code)
  }

  public func consume(
    _ consumed: Substring, from index: String.Index
  ) -> String.Index? {
    let result = vm.execute(
      input: consumed.base, in: index..<consumed.endIndex, .partialFromFront)
    assert(result?.range ==
           referenceVM.execute(
            input: consumed.base, in: index..<consumed.endIndex, .partialFromFront
           )?.range)

    return result?.range.upperBound
  }
}

// TODO: We'll want to bake backwards into the engine
extension RegexConsumer: BackwardCollectionConsumer {
  public func consumeBack(
    _ consumed: Substring, from index: String.Index
  ) -> String.Index? {
    var i = consumed.startIndex
    while true {
      if let end = consume(consumed[..<index], from: i), end == index {
        return i
      } else if i == index {
        return nil
      } else {
        consumed.formIndex(after: &i)
      }
    }
  }
}

extension RegexConsumer: StatelessCollectionSearcher {
  public typealias Searched = Substring

  // TODO: We'll want to bake search into the engine so it can
  // take advantage of the structure of the regex itself and
  // its own internal state
  public func search(
    _ searched: Substring, from index: String.Index
  ) -> Range<String.Index>? {
    ConsumerSearcher(consumer: self).search(searched, from: index)
  }
}

// TODO: Bake in search-back to engine too
extension RegexConsumer: StatelessBackwardCollectionSearcher {
  public func searchBack(
    _ searched: Substring, from index: String.Index
  ) -> Range<String.Index>? {
    ConsumerSearcher(consumer: self).searchBack(searched, from: index)
  }
}