using System.CodeDom.Compiler;
using System.Collections.Generic;
using System.Collections;
using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Serialization;
using System.Text.RegularExpressions;
using System.Text;
using System;

class Solution
{

    //step history
    public static char[] steps;

    //current altitude at end of step
    public static int altitude_current = 0;

    //altitude at start of step
    public static int altitude_last = 0;

    //total valleys
    public static int total_vallies = 0;

    //if we are in a valley right now
    private static bool In_Valley;

    //test case for "consecutive steps"
    public static int min_valley_length = 2;

    public static bool in_valley
    {

        get
        {
            return In_Valley;
        }

        set
        {
            if (In_Valley)
            {
                In_Valley = value;
            }
            else
            {
                In_Valley = value;
            };
        }
    }

    //length of the current valley
    public static int current_valley_length = 0;

    // Complete the countingValleys function below.
    static int countingValleys(int n, string s)
    {

        //step history, new each time
        steps = s.ToCharArray();

        //current altitude at end of step, reset this value
        altitude_current = 0;

        //altitude at start of step, reset this value 
        altitude_last = 0;

        //if we are in a valley, track the progress
        current_valley_length = 0;

        int counter = 0;

        in_valley = false;


        //process step history
        //the step back history if you will =P
        foreach (char step in steps)
        {

            counter += 1;

            // process the steps
            if (step.Equals('D'))
            {
                altitude_current -= 1;
            }

            if (step.Equals('U') )
            {
                altitude_current += 1;
            }

            if (altitude_last == 0 && altitude_current == -1)
            {
                //we just stepped into a valley
                in_valley = true;
            }

            if (altitude_last == -1 && altitude_current == 0)
            {
                // back above sea level
                if(current_valley_length >= min_valley_length)
                {
                    total_vallies += 1;
                    Console.WriteLine("Exited a Valley!");
                }

                in_valley = false;
            }

            //track valley length
            if (in_valley)
            {
                current_valley_length += 1;
            }

            Console.WriteLine("------------------------------------------------------------------------");
            Console.WriteLine("step: " + counter + "processed. Value is: " + step);
            Console.WriteLine("Current Altitude: " + altitude_current);
            Console.WriteLine("Previous Altitude: " + altitude_last);
            Console.WriteLine("In Valley? : " + in_valley + "| Valley Length: " + current_valley_length);
            Console.WriteLine("Total Vallies Discovered: " + total_vallies);

            //store the last altitude
            altitude_last = altitude_current;

        }

        return total_vallies;
    }




    static void Main(string[] args)
    {
        TextWriter textWriter = new StreamWriter(@System.Environment.GetEnvironmentVariable("OUTPUT_PATH"), true);

        int n = Convert.ToInt32(Console.ReadLine());

        string s = Console.ReadLine();

        int result = countingValleys(n, s);

        textWriter.WriteLine(result);

        textWriter.Flush();
        textWriter.Close();
    }
}
