import UIKit

// MARK: - Method 1

extension Array {
    func nFilter(_ includeElement: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        for x in self where includeElement(x) {
            result.append(x)
        }
        return result
    }
    
    func nReduce<T>(_ initial: T, _ combine: (T, Element) -> T) -> T {
        var result = initial
        for x in self {
            result = combine(result, x)
        }
        return result
    }
}

func sumOfPrimesMethod1(start: Int, end: Int) -> Int {
    func nEnumerateInterval(a: Int, b: Int) -> [Int] {
        var elements = [Int]()
        for i in a...b {
            elements.append(i)
        }
        return elements
    }
    // nEnumerateInterval(a, b).nFilter(isPrime).nReduce(0, +)
    return nEnumerateInterval(a: start, b: end).nFilter(nIsPrime(_:)).nReduce(0, +)
}

// MARK: - Method 2

func sumOfPrimesMethod2(start: Int, end: Int) -> Int {
    indirect enum StreamInt {
        case empty
        case value(Int, () -> StreamInt)
        
        // SICP 中，filter 对流进行处理，如果符合条件，则递归 filter，从而让 当前元素 和 下一个符合的元素 组成 stream；如果不符合条件，则 filter 递归。

        func sFilter(_ includeElement: (StreamInt) -> Bool) -> StreamInt {
            guard case StreamInt.value(_, let next) = self else { return .empty }
            if includeElement(self) {
                return self
            } else {
                return next().sFilter(includeElement)
            }
        }
        
        func sReduce(_ initial: Int, _ combine: (Int, StreamInt) -> Int) -> Int {
            let result = combine(initial, self)
            return result
        }
    }

    func sEnumerateInterval(a: Int, b: Int) -> StreamInt {
        guard a <= b else { return .empty }
        return .value(a) { () -> StreamInt in
            return sEnumerateInterval(a: a+1, b: b)
        }
    }
    
    func sIsPrime(_ value: StreamInt) -> Bool {
        guard case StreamInt.value(let v, _) = value else { return false }
        guard v != 2 else { return true }
        guard v > 2 else { return false }
        
        for i in 2...v-1 {
            if v % i == 0 {
                return false
            }
        }
        return true
    }
    
    // sEnumerateInterval(a, b).sFilter(isPrime).sReduce(0, +)
    return sEnumerateInterval(a: start, b: end).sFilter(sIsPrime(_:)).sReduce(0) { (result, stream) -> Int in
        guard case StreamInt.value(let v, _) = stream else { return result }
        return result + v
    }
}

// MARK: - Method 3

func sumOfPrimesMethod3(start: Int, end: Int) -> Int {
    // 递归求解
    // 本质上是数据自动生成，触发生成下一个数，并对其进行处理。
    // 一种主动流
    // 但是不够直观，看不出 管道/流 的形式
    func iterator(_ value: Int, accum: Int) -> Int {
        guard value <= end else { return accum }
        if nIsPrime(value) {
            return iterator(value + 1, accum: accum + value)
        } else {
            return iterator(value + 1, accum: accum)
        }
    }
    return iterator(start, accum: 0)
}

func streamSumOfPrimes(start: Int, end: Int) -> Int {
    return 0
}

func nIsPrime(_ value: Int) -> Bool {
    guard value != 2 else { return true }
    guard value > 2 else { return false }
    
    for i in 2...value-1 {
        if value % i == 0 {
            return false
        }
    }
    return true
}

// MARK: - Execute

var str = "Hello, playground"

let res1 = sumOfPrimesMethod1(start: 4, end: 10)
let res2 = sumOfPrimesMethod2(start: 4, end: 10)
print("result = \(res1), \(res2)")
    
/*
enum Result<T> {
    case success(T)
    case failure(Error)
}

extension Result {
    func map<O>(_ mapper: (T) -> O) -> Result<O> {
        switch self {
        case .failure(let error):
            return .failure(error)
        case .success(let value):
            return .success(mapper(value))
        }
    }
}

precedencegroup ChainingPrecedence {
    associativity: left
    higherThan: TernaryPrecedence
}

infix operator <^> : ChainingPrecedence

func <^><T, O>(lhs: (T) -> O, rhs: Result<T>) -> Result<O> {
    return rhs.map(lhs)
}
*/
