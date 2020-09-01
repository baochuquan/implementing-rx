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
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element
}

extension ObservableType {
    func map<Result>(_ transform: @escaping (Element) throws -> Result) -> Observable<Result> {
        return Observable<Result> { (observer) in   // observer 为原始 observer
            // 此闭包可看成是一个 eventGenerator
            // 向原始 observable 中传入一个中间 map observer，即由中间 map observer 替换原始 observer 监听原始事件
            // 中间 map observer 对原始事件进行转换后，转发给原始 observer
            return self.subscribe(observer: Observer { (event) in
                print("Map observer = \(observer)")
                switch event {
                case .next(let element):
                    do {
                        try observer.on(event: .next(transform(element)))
                    } catch {
                        observer.on(event: .error(error))
                    }
                case .error(let error):
                    observer.on(event: .error(error))
                case .completed:
                    observer.on(event: .completed)
                }
            })
        }
    }
}

class Observable<Element>: ObservableType {
    // 定义 发布事件 的闭包
    private let _eventGenerator: (Observer<Element>) -> Disposable
    
    init(_ eventGenerator: @escaping (Observer<Element>) -> Disposable) {
        _eventGenerator = eventGenerator
    }
    
    // 实现 订阅操作 的协议，内部生成事件
    func subscribe<O: ObserverType>(observer: O) -> Disposable where O.Element == Element {
        let sink = Sink(forward: observer, eventGenerator: _eventGenerator)
        sink.run()
        return sink
    }
}

class Producer<Element>: Observable<Element> {
}

class MapObservable<SourceType, ResultType>: Producer<ResultType> {
    typealias Transform = (SourceType) throws -> ResultType
    private let _forward: Observable<SourceType>
    private let _transform: Transform
    
    init(forward: Observable<SourceType>, transform: @escaping Transform) {
        self._forward = forward
        self._transform = transform
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        
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
    private let _eventGenerator: (Observer<O.Element>) -> Disposable
    private let _composite = CompositeDisposable()
    
    init(forward: O, eventGenerator: @escaping (Observer<O.Element>) -> Disposable) {
        _forward = forward
        _eventGenerator = eventGenerator
    }
    
    func run() {
        // 通过一个中间 Observer 接收原始事件
        // 根据 CompositionDisposable 的状态决定是否传递给原始 Observer
        let observer = Observer<O.Element>(forward)
        // 执行发布事件
        // 将返回值 Disposable 加入到 CompositeDisposable 中进行管理
        _composite.add(disposable: _eventGenerator(observer))
    }
    
    private func forward(event: Event<O.Element>) {
        guard !_disposed else { return }
        // 事件传递给原始 observer
        print("Sink _forward = \(_forward)")
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
        _composite.dispose()
    }
}

class MapSink<SourceType, O: ObserverType>: Sink<Observer>, ObserverType {
    
}

// MARK: - Cancelable

protocol Cancelable : Disposable {
    /// Was resource disposed.
    var isDisposed: Bool { get }
}

//private class SinkDisposer: Cancelable {
//    private var _isDisposed: Bool
//    private var _sink: Disposable?
//    private var _
//
//    var isDisposed: Bool {
//        return _isDisposed
//    }
//
//    func dispose() {
//        sink.dis
//    }
//}

// MARK: - Test

let observable = Observable<Int> { (observer) -> Disposable in  // observer 为 MapObserver
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
