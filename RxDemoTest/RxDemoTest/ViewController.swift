//
//  ViewController.swift
//  RxDemoTest
//
//  Created by baochuquan on 2020/8/27.
//  Copyright © 2020 baochuquan. All rights reserved.
//

import UIKit
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
        return Observable<Result> { (observer) in   //
            // 此闭包可看成是一个 eventGenerator
            return self.subscribe(observer: Observer { (event) in
                print("Map observer = \(observer)") // observer 是 sink 中的 _forward，即原始 observer
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
        // 通过一个中间 Observer 对原始 Observer 进行封装，用于过滤事件的传递
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

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // MARK: - Test

        let observable = Observable<Int> { (observer) -> Disposable in  // observer 为 mapObserver
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

    }

    
}

