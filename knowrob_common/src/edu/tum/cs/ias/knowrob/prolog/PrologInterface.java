package edu.tum.cs.ias.knowrob.prolog;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.Vector;

import edu.tum.cs.ias.knowrob.utils.ros.RosUtilities;
import jpl.*;


public class PrologInterface {
    
    /**
     *  Initialize a local Prolog engine with the ROS package given
     *  as argument
     *  
     *  @param initPackage String with the name of the package to be used for initialization
     *  
     */
    public static void initJPLProlog(String initPackage) {
        try {
            Vector<String> args= new Vector<String>(Arrays.asList(jpl.fli.Prolog.get_default_init_args()));
            args.add( "-G256M" );
            //args.add( "-q" );
            args.add( "-nosignals" );
            
            String rosprolog = RosUtilities.rospackFind("rosprolog");
            System.err.println(rosprolog+"/prolog/init.pl");
            jpl.fli.Prolog.set_default_init_args( args.toArray( new String[0] ) );

            // load the appropriate startup file for this context
            new jpl.Query("ensure_loaded('"+rosprolog+"/prolog/init.pl"+"')").oneSolution();
            new jpl.Query("register_ros_package('"+initPackage+"')").oneSolution();

        } catch(Exception e) {
            e.printStackTrace();
        }
    }
    
    
	/**
	 * Wrapper around the JPL Prolog query interface. Assumes a Prolog engine to be
	 * initialized, e.g. using initJPLProlog
	 * 
	 * @param query A query string in common SWI Prolog syntax
	 * @return A HashMap<VariableName, ResultsVector>
	 */
	@SuppressWarnings("rawtypes")
	public static HashMap<String, Vector<String>> executeQuery(String query) {
		
		HashMap<String, Vector<String>> result = new HashMap< String, Vector<String> >();
		Hashtable[] solutions;

		synchronized(jpl.Query.class) {
		
    		Query q = new Query( "expand_goal(("+query+"),_9), call(_9)" );

    		if(!q.hasSolution())
    			return new HashMap<String, Vector<String>>();
    		
    		
    		solutions = q.allSolutions();
    		for (Object key: solutions[0].keySet()) {
    			result.put(key.toString(), new Vector<String>());
    		}
    		
    		// Build the result
    		for (int i=0; i<solutions.length; i++) {
    			Hashtable solution = solutions[i];
    			for (Object key: solution.keySet()) {
    				String keyStr = key.toString();
    				if (!result.containsKey( keyStr )) {

    					// previously unknown column, add result vector
    					Vector<String> resultVector = new Vector<String>(); 
    					resultVector.add( i, solution.get( key ).toString() );
    					result.put(keyStr, resultVector);

    				}
    				// Put the solution into the correct vector
    				Vector<String> resultVector = result.get( keyStr );
    				resultVector.add( i, solution.get( key ).toString() );
    			}
    		}
		}
		// Generate the final QueryResult and return
		return result;
	}
	
	/**
	 * Convert Prolog list (dotted pairs) into a Java ArrayList
	 * 
	 * @param rest
	 * @return
	 */
    public static ArrayList<String[]> dottedPairsToArrayList(String rest) {
        
        ArrayList<String[]> bindings = new ArrayList<String[]>();
        while(rest.length()>0) {

            String[] l = rest.split("'\\.'", 2);
            if((l[0].equals("")) || (l[0].equals("("))) {
               rest=l[1]; continue;

            } else {
            	if (l[0].length() > 2)            	
            		bindings.add(new String[]{l[0].substring(1, l[0].length()-2).split(", ")[0]});
                                
                if(l.length>1) {
                    rest=l[1];  continue;
                } else break;
            }
            
        }
        return bindings;
      }

    
    /**
     * Removes single quotes at the start and end of a string if applicable. 
     * 
     * Useful when dealing with OWL IRI identifiers that need to be 
     * in single quotes in Prolog. 
     * 
     * @param str String with or without single quotes at the beginning and end
     * @return String without single quotes at the beginning and end
     */
    public static String removeSingleQuotes(String str) {
        if(str.startsWith("'"))
            str = str.substring(1);
        
        if(str.endsWith("'"))
            str = str.substring(0, str.length()-1);
        return str;
    }
    

    /**
     * Adds single quotes at the start and end of a string if applicable. 
     * 
     * Useful when dealing with OWL IRI identifiers that need to be 
     * in single quotes in Prolog. 
     * 
     * @param str String with or without single quotes at the beginning and end
     * @return String with single quotes at the beginning and end
     */
    public static String addSingleQuotes(String str) {
        return "'"+removeSingleQuotes(str)+"'";
    }
    
    
    /**
     * Splits an IRI to extract the identifier part after the 
     * hash sign '#'
     * 
     * @param iri IRI of the form http://...#value
     * @return The identifier value
     */
    public static String valueFromIRI(String iri) {
        String[] ks = iri.split("#");
           if(ks.length>1) {
               String res = ks[1].replaceAll("'", "");
               return res;
           }
           else return iri;
     }
    
}
