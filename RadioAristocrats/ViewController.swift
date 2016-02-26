//
//  ViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPageViewControllerDataSource {

    private struct ContentViewControllers {
        static let Count = 3 // Stream, A-Music, Jazz
    }
    
    private var _pageViewController: UIPageViewController!

    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup PageViewController
        if let pageVC = storyboard?.instantiateViewControllerWithIdentifier("PageViewController") as? UIPageViewController {
            _pageViewController = pageVC
        } else {
            print("*** Type casting error.")
        }
        _pageViewController.dataSource = self
        if let startingViewController: PageContentViewController = viewControllerAtIndex(0) as? PageContentViewController {
            _pageViewController.setViewControllers([startingViewController], direction: .Forward, animated: false, completion: nil)
        } else {
            print("*** Type casting error.")
        }
        _pageViewController.view.frame = CGRectMake(0, 0, view.bounds.width, view.bounds.height)
        _pageViewController.willMoveToParentViewController(self)
        addChildViewController(_pageViewController)
        _pageViewController.didMoveToParentViewController(self)
        view.addSubview(_pageViewController.view)
        
        // Setup PageControl appearance
        let pageControl = UIPageControl.appearance()
        pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
        pageControl.currentPageIndicatorTintColor = UIColor.darkGrayColor()
        pageControl.backgroundColor = UIColor.clearColor()
    }

    // MARK: - UIPageViewController DataSource
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        
        if let viewController = viewController as? PageContentViewController {
            var index = viewController.pageIndex!
            index++
            if (index >= ContentViewControllers.Count) {
                return nil
            }
            return viewControllerAtIndex(index)
        } else {
            print("*** Type casting error.")
            return nil
        }

    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        
        if let viewController = viewController as? PageContentViewController {
            var index = viewController.pageIndex!
            if (index <= 0) {
                return nil
            }
            index--
            return viewControllerAtIndex(index)
        } else {
            print("*** Type casting error.")
            return nil
        }
    }
    
    func viewControllerAtIndex(index: Int) -> UIViewController? {
        if (index >= ContentViewControllers.Count) {
            return nil
        }
        
        if let pageContentViewController = storyboard?.instantiateViewControllerWithIdentifier("PageContentViewController") as? PageContentViewController {
            pageContentViewController.pageIndex = index
            return pageContentViewController
        } else {
            print("*** Type casting error.")
            return nil
        }
    }
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return ContentViewControllers.Count
    }
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }
    
}
