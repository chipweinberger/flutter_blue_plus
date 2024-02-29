package com.lib.flutter_blue_plus;

import java.util.LinkedList

class LimitedQueue<T>(private val limit: Int) : LinkedList<T>() {

    override fun add(element: T): Boolean {
        if (size >= limit) {
            removeFirst() // Remove the oldest element if the limit is reached
        }
        return super.add(element) 
    }

    override val size: Int
        get() = super.size

    override fun toString(): String {
        return super.toString()
    }
}