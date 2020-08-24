import Foundation

// MARK: - Event

enum Event<Element> {
    case next(Element)
    case error(Error)
    case completed
}

// MARK: - Observer

protocol ObserverType {
    associatedtype Element
    
    // 监听事件
    func on(event: Event<Element>)
}

class Observer<Element>: ObserverType {
    
    // 订阅者如何处理事件的闭包
    private let _handler: (Event<Element>) -> Void
    
    init(_ handler: @escaping (Event<Element>) -> Void) {
        _handler = handler
    }
    
    // 实现 监听事件 的协议，内部处理事件
    func on(event: Event<Element>) {
        // 处理事件
        _handler(event)
    }
}

// MARK: - Observable

protocol ObservableType {
    associatedtype Element
    
    // 订阅操作
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element
}

class Observable<Element>: ObservableType {
    // 定义 发布事件 的闭包
    private let _eventGenerator: (Observer<Element>) -> Void
    
    init(_ eventGenerator: @escaping (Observer<Element>) -> Void) {
        _eventGenerator = eventGenerator
    }
    
    // 实现 订阅操作 的协议，内部生成事件
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element {
        _eventGenerator(observer as! Observer<Element>)
    }
}

let observable = Observable<Int> { (observer) in
    print("send 0")
    observer.on(event: .next(0))    // observer.on(event: .next(0).map({ $0 * 2 }))
    print("send 1")
    observer.on(event: .next(1))
    print("send 2")
    observer.on(event: .next(2))
    print("send 3")
    observer.on(event: .next(3))
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        print("send completed")
        observer.on(event: .completed)
    }
}

let observer = Observer<Int> { (event) in
    switch event {
    case .next(let value):
        print("recive \(value)")
    case .error(let error):
        print("recive \(error)")
    case .completed:
        print("recive completed")
    }
}

observable.subscribe(observer: observer)
