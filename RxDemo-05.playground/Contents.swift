import Foundation

func rxAbstractMethod(file: StaticString = #file, line: UInt = #line) -> Swift.Never {
    fatalError("Abstract Method", file: file, line: line)
}

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
    
    init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        self._handler = observer.on
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
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element
    
    func asObservable() -> Observable<Element>
}

class Observable<Element>: ObservableType {
    // 抽象类
//    // 定义 发布事件 的闭包，有子类来定义
//    private let _eventGenerator: (Observer<Element>) -> Disposable
//
//    init(_ eventGenerator: @escaping (Observer<Element>) -> Disposable) {
//        _eventGenerator = eventGenerator
//    }

    // 实现 订阅操作 的协议，内部生成事件
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element {
        rxAbstractMethod()
    }

    func asObservable() -> Observable<Element> {
        return self
    }
}

class Producer<Element>: Observable<Element> {
    // 实现 订阅操作 的协议，内部生成事件
    override func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element {
        return run(observer: observer)
    }
    
    func run<O: ObserverType>(observer: O) -> Disposable where O.Element == Element {
        rxAbstractMethod()
    }
}

// MARK: - Disposable

protocol Disposable {
    // 取消订阅
    func dispose()
}

final class AnonymousDisposable: Disposable {
    // AnonymousDisposable 封装了 取消订阅时附带操作 的闭包
    private let _disposeHandler: () -> Void
    
    init(_ disposeClosure: @escaping () -> Void) {
        _disposeHandler = disposeClosure
    }
    
    func dispose() {
        _disposeHandler()
    }
}

class CompositeDisposable: Disposable {
    // 可用于管理一组 Disposable 的 CompositeDisposable

    // 判断是否已销毁的标志位
    private(set) var isDisposed: Bool = false
    // 管理一组 Disposable
    private var disposables: [Disposable] = []
    
    init() {}
    
    func add(disposable: Disposable) {
        if isDisposed {
            disposable.dispose()
            return
        }
        disposables.append(disposable)
    }
    
    func dispose() {
        guard !isDisposed else { return }
        // 销毁所有 disposable，并设置标志位
        disposables.forEach {
            $0.dispose()
        }
        isDisposed = true
    }
}

class Sink<O: ObserverType>: Disposable {
    private var _disposed: Bool = false
    private let _forward: O
    private let _composite = CompositeDisposable()
    
    init(forward: O) {
        _forward = forward
    }
    
    func forward(event: Event<O.Element>) {
        guard !_disposed else { return }
        // 事件传递给原始 observer
        _forward.on(event: event)
        // 通过 composite 管理 error、completed 时，自动取消订阅
        switch event {
        case .completed, .error(_):
            dispose()
        default:
            break
        }
    }
    
    func dispose() {
        _disposed = true
        print("dispose execute")
        _composite.dispose()
    }
}

// MARK: - Anonymous

extension ObservableType {
    static func create(_ eventGenerator: @escaping (Observer<Element>) -> Disposable) -> Observable<Element> {
        return AnonymousObservable(eventGenerator: eventGenerator)
    }
}

class AnonymousObserver<O: ObserverType>: Sink<O>, ObserverType {
    typealias Element = O.Element
    
    override init(forward: O) {
        super.init(forward: forward)
    }
    
    func on(event: Event<Element>) {
        switch event {
        case .next(let element):
            self.forward(event: .next(element))
        case .error(let error):
            self.forward(event: .error(error))
            self.dispose()
        case .completed:
            self.forward(event: .completed)
            self.dispose()
        }
    }
    
    func run(parent: AnonymousObservable<Element>) -> Disposable {
        parent._eventGenerator(Observer(self))
    }
}

class AnonymousObservable<Element>: Producer<Element> {
    let _eventGenerator: (Observer<Element>) -> Disposable
    
    init(eventGenerator: @escaping (Observer<Element>) -> Disposable) {
        self._eventGenerator = eventGenerator
    }
    
    override func run<O>(observer: O) -> Disposable where Element == O.Element, O : ObserverType {
        let sink =  AnonymousObserver(forward: observer)
        sink.run(parent: self)
        return sink
    }
}

// MARK: - Map

extension ObservableType {
    func map<Result>(_ transform: @escaping (Element) throws -> Result) -> Observable<Result> {
        return MapObservable(source: self.asObservable(), transform: transform)
    }
}

class MapObserver<Source, Result, O: ObserverType>: Sink<O>, ObserverType {
    typealias Element = Source
    typealias Result = O.Element
    typealias Transform = (Source) throws -> Result
    private let _transform: Transform
    
    init(forward: O, transform: @escaping Transform) {
        self._transform = transform
        super.init(forward: forward)
    }
    
    func on(event: Event<Element>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try _transform(element)
                self.forward(event: .next(mappedElement as! O.Element))
            } catch {
                self.forward(event: .error(error))
            }
        case .error(let error):
            self.forward(event: .error(error))
            self.dispose()
        case .completed:
            self.forward(event: .completed)
            self.dispose()
        }
    }
}

class MapObservable<Source, Result>: Producer<Result> {
    typealias Transform = (Source) throws -> Result
    private let _transform: Transform
    private let _source: Observable<Source>
    
    init(source: Observable<Source>, transform: @escaping Transform) {
        self._source = source
        self._transform = transform
    }

    override func run<O: ObserverType>(observer: O) -> Disposable where Result == O.Element {
        let sink = MapObserver(forward: observer, transform: self._transform)
        self._source.subscribe(observer: sink)
        return sink
    }
}

// MARK: - Test

let observable = Observable<Int>.create { (observer) -> Disposable in  // observer 为 MapObserver
    print("send 0")
    observer.on(event: .next(0))
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
    return AnonymousDisposable {
        print("dispose")
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

let disposable = observable.map { $0 * 2 }.map { $0 + 1 }.subscribe(observer: observer)

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    disposable.dispose()
}
