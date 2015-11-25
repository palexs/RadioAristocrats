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
    
    var pageViewController : UIPageViewController!

    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup PageViewController
        pageViewController = storyboard?.instantiateViewControllerWithIdentifier("PageViewController") as! UIPageViewController
        pageViewController.dataSource = self
        let startingViewController: PageContentViewController = viewControllerAtIndex(0) as! PageContentViewController
        pageViewController.setViewControllers([startingViewController], direction: .Forward, animated: false, completion: nil)
        pageViewController.view.frame = CGRectMake(0, 0, view.bounds.width, view.bounds.height)
        startingViewController.willMoveToParentViewController(pageViewController)
        addChildViewController(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMoveToParentViewController(self)
        
        // Setup PageControl
        let pageControl = UIPageControl.appearance()
        pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
        pageControl.currentPageIndicatorTintColor = UIColor.darkGrayColor()
        pageControl.backgroundColor = UIColor.clearColor()
    }

    // MARK: - UIPageViewController DataSource
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        
        var index = (viewController as! PageContentViewController).pageIndex!
        index++
        if (index >= ContentViewControllers.Count) {
            return nil
        }
        
        return viewControllerAtIndex(index)
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        
        var index = (viewController as! PageContentViewController).pageIndex!
        if (index <= 0) {
            return nil
        }
        index--
        
        return viewControllerAtIndex(index)
        
    }
    
    func viewControllerAtIndex(index : Int) -> UIViewController? {
        if (index >= ContentViewControllers.Count) {
            return nil
        }
        
        let pageContentViewController = storyboard?.instantiateViewControllerWithIdentifier("PageContentViewController") as! PageContentViewController
        
        pageContentViewController.pageIndex = index
        
        return pageContentViewController
    }
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return ContentViewControllers.Count
    }
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }

}

