package com.example.swift

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.example.swift.ui.theme.JavaKitSampleAppTheme
import java.util.function.Predicate

open class HelloSwift : ComponentActivity() {
    init {
        System.loadLibrary("JavaKitExample")
    }

    external fun sayHello(x: Int, y: Int): Int
    external fun throwMessageFromSwift(message: String)

    private fun getGreeting(): String {
        val result = sayHello(17, 25)
        return "$result"
    }

    var value: Double = 0.0
    var name: String = "Java"

    fun sayHelloBack(i: Int): Double {
        return value
    }

    fun greet(name: String) {
        println("Salutations, $name")
    }

    fun lessThanTen(): Predicate<Int> {
        val predicate = Predicate<Int> { it < 10 }
        return predicate
    }

    fun doublesToStrings(doubles: DoubleArray): Array<String?> {
        val size = doubles.count()
        var strings: Array<String?> = arrayOfNulls(doubles.count())

        doubles.forEachIndexed { index, element ->
            strings[index] = "$element"
        }

        return strings
    }

    fun throwMessage(message: String) {
        throw Exception(message)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            JavaKitSampleAppTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Greeting(
                        name = getGreeting(),
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "sayHello(17, 25) = $name",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    JavaKitSampleAppTheme {
        Greeting("Android")
    }
}

class HelloSubclass(private val greeting: String = "Swift"): HelloSwift() {
    fun greetMe() {
       super.greet(greeting)
    }
}