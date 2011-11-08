package edu.tum.cs.ias.knowrob;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Vector;
import org.apache.commons.lang.StringUtils;

import com.google.common.base.CaseFormat;
import com.google.common.base.Joiner;

import net.sf.json.*;
import edu.tum.cs.ias.knowrob.prolog.PrologInterface;

public class PlanExporter {


    public static final String MAPPING_CONFIG_FILE = "etc/knowrob2cpl.json";

    /**
     * List of all action instances of the plan in the correct order, e.g.
     * "action1", "action2", ...
     */
    private ArrayList<String> plan;

    /**
     * mapping from KnowRob concepts to CPL identifiers
     */
    private JSONObject knowrobToCPL;
    private HashMap<String, String> designators;
    private int inst_counter = 100;

    public PlanExporter() throws IOException {

        designators = new HashMap<String, String>();
        knowrobToCPL = readCplMapping(MAPPING_CONFIG_FILE);
        plan = new ArrayList<String>();
    }

    public String exportPlanToCPL(String plan_name) {
		
        plan_name = PrologInterface.addSingleQuotes(plan_name);
		String res = "";

		HashMap<String, Vector<String>> plan_steps = 
			PrologInterface.executeQuery("plan_subevents("+ plan_name +", Steps)");

		
		for(String dottedpairs : (plan_steps.get("Steps"))) {
		    

		    for(String[] actions: PrologInterface.dottedPairsToArrayList(dottedpairs)) {
		        
		        for(String action : new ArrayList<String>(Arrays.asList(actions))) {
		    
		            HashMap<String, Vector<String>> params = 
		                PrologInterface.executeQuery("class_properties("+action+", Prop, Val)");

		            String obj_desig="", loc_desig="", device="";

		            for(int i=0;i<params.get("Prop").size();i++) {

		                String prop = PrologInterface.removeSingleQuotes(params.get("Prop").get(i));
		                String val  = PrologInterface.removeSingleQuotes(params.get("Val").get(i));


		                if(prop.endsWith("objectActedOn")) {

		                    obj_desig = objectDesignatorFromOWLclass(val);

		                } else if(prop.endsWith("toLocation") || prop.endsWith("fromLocation")) {

		                    int idx = params.get("Prop").lastIndexOf(PrologInterface.addSingleQuotes("http://ias.cs.tum.edu/kb/knowrob.owl#objectActedOn"));

		                    // set object parameter ('location for object') if objectActedOn is set
		                    String obj = "";
		                    if(idx>-1 && params.get("Val").contains(idx)) {
		                        obj = params.get("Val").get(idx);
		                    }
		                    
		                    loc_desig = locationDesignatorFromOWLclass(val, obj);
		                    
		                } else if(prop.endsWith("deviceUsed")) {
		                	device = val;
		                }
		                
		            }


		            // create action goal
		            String rplAction = knowrobToCpl(action);

		            String action_spec = "";
		            if(rplAction.endsWith("object-in-hand")) {
		                action_spec = "(achieve (object-in-hand "+ obj_desig +" ?side))";

		            } else if(rplAction.endsWith("object-placed-at")) {
		                action_spec = "(achieve (object-placed-at "+ obj_desig +" "+ loc_desig +"))";

		            } else if(rplAction.endsWith("arm-parked")) {
		                action_spec = "(achieve (arm-parked "+device+"))";

		            } else if(rplAction.endsWith("arms-at")) {
		                action_spec = "(achieve (arms-at " + loc_desig + "))";

		            } else if(rplAction.endsWith("looking-at")) {
		                action_spec = "(achieve (looking-at "+ loc_desig +"))";

		            } else if(rplAction.endsWith("perceive-all")) {
		                action_spec = "(perceive-all "+ obj_desig +")";

		            } else if(rplAction.endsWith("perceive")) {
		            	action_spec = "(perceive "+ obj_desig +")"; 

		            }  else if(rplAction.endsWith("loc")) {
		            	action_spec = "(achieve (loc "+ loc_desig +"))"; 

		            } else if(rplAction.endsWith("gripper-opened")) {
		            	action_spec = "(achieve (gripper-opened "+ device +"))";
		            }

		            plan.add(action_spec);

		        }

		    }
		}
        


		// export to string
		res += "(def-top-level-plan " + lispify(plan_name) + " () \n";
		res += "(with-designators (\n\n      ";
		res += Joiner.on("\n      ").join(designators.values());
		
		res += ")\n\n";
		
		res += Joiner.on("\n").join(plan);
		
		res += "))";
		
		return res;
	}

    
    
    
    /**
     * Create an object designator based on an OWL class specification
     * 
     * @param objdef OWL class specification of an object
     * @return       ID of the generated designator
     */
    private String objectDesignatorFromOWLclass(String objdef) {

        // create the appropriate object designators

        HashMap<String, Vector<String>> types = PrologInterface
                .executeQuery("rdf_has(" + PrologInterface.addSingleQuotes(objdef) + ", rdf:type, T)");

        String obj_type = "";
        String obj_inst = "";

        String obj_desig = "";
        
        // first case: objdef is an instance
        if (!types.get("T").isEmpty()) {
            
            obj_type = knowrobToCpl(types.get("T").firstElement());
            obj_inst = knowrobToCpl(objdef);
            
            obj_desig = "(" + lispify(obj_inst) + " (an object\n             `((name ," + knowrobToCpl(obj_inst) + ")\n              (type ,"+lispify(obj_type)+")) ))\n";

        } else { // second case: objdef is a class
            
            obj_type = knowrobToCpl(objdef);
            obj_inst = knowrobToCpl(instanceFromClass(obj_type));
            
            obj_desig = "(" + lispify(obj_inst) + " (an object\n             `((type ," + knowrobToCpl(obj_type) + ")) ))\n";
        }
        // TODO: (part-of <object-desig>)

        designators.put(obj_inst, obj_desig);
        return obj_inst;
    }

    
    /**
     * Create a location designator based on an OWL class specification
     * 
     * @param loc
     *            OWL class specification of a location
     * @return ID of the generated designator
     */
    private String locationDesignatorFromOWLclass(String loc, String obj_desig) {

        
        
        
        HashMap<String, Vector<String>> params = PrologInterface
                .executeQuery("class_properties(" + PrologInterface.addSingleQuotes(loc) + ", Prop, Val); " +
                		      "owl_has("+PrologInterface.addSingleQuotes(loc)+", Prop, Val)");
        
        
        loc = knowrobToCpl(loc);
        
        // recursively build the location designator
        String loc_desig = "(" + loc + " ";
        loc_desig += "(a location `(";
        
        
        if(params!=null && params.get("Prop")!=null) {
        
            for (int i = 0; i < params.get("Prop").size(); i++) {
    
                String prop = PrologInterface.removeSingleQuotes(params.get("Prop").get(i));
                String val = params.get("Val").get(i);
    
                
                if ((prop.endsWith("in-ContGeneric")
                        || prop.endsWith("in-UnderspecifiedContainer")
                        || prop.endsWith("into-UnderspecifiedContainer") 
                        || prop.endsWith("from-UnderspecifiedLocation"))) {
    
                    loc_desig += "\n              (in ,"
                            + knowrobToCpl(locationDesignatorFromOWLclass(val, obj_desig));
                    
                    if(!obj_desig.isEmpty())
                        loc_desig += ")\n              (of ," + obj_desig + ")";
    
                } else if (prop.endsWith("to-UnderspecifiedLocation")
                        || prop.endsWith("on-Physical")
                        || prop.endsWith("aboveOf")
                        || prop.endsWith("inCenterOf")) {
                    loc_desig += "\n              (on ,"
                            + knowrobToCpl(locationDesignatorFromOWLclass(val, obj_desig));
                    
                    if(!obj_desig.isEmpty())
                        loc_desig += ")\n              (for ," + obj_desig + ")";
    
                } else if (prop.endsWith("inReachOf") ||
                        prop.endsWith("inFrontOf-Generally")) {
                    loc_desig += "\n              (to reach ," + knowrobToCpl(objectDesignatorFromOWLclass(val)) + ")";
    
                } else if (prop.endsWith("visibleFrom")) {
                    loc_desig += "\n              (to see ," + knowrobToCpl(objectDesignatorFromOWLclass(val)) + ")";
    
                } else if (prop.endsWith("orientation")) {
                    loc_desig += "\n              (pose ," + knowrobToCpl(objectDesignatorFromOWLclass(val)) + ")";
    
                } else if (prop.endsWith("type")) {
                    loc_desig += "\n              (type ," +  knowrobToCpl(val) + ")";
    
                } else {
                    loc_desig += "\n              (name ," +  knowrobToCpl(val) + ")";
                }
    
            }
        }
        loc_desig += "))\n";

        designators.put(loc, loc_desig);
        return loc;
    }


    
    /**
     * Convert KnowRob identifier to CPL
     * 
     * If there is a mapping defined in the knowrobToCPL HashMap, this
     * mapping will be used. Otherwise, the methods returns a 'lispified'
     * string, i.e. a string that is converted from CamelCase to 
     * lower-case-hyphenated 
     * 
     * @param val KnowRob identifier
     * @return Lispified identifier that can be used in CPL
     */
    private String knowrobToCpl(String val) {
        
        if(knowrobToCPL.containsKey(PrologInterface.valueFromIRI(val))) {
            return knowrobToCPL.getString(PrologInterface.valueFromIRI(val));
            
        } else {
            
            // check whether there are definitions for superclasses, take the first one
            HashMap<String, Vector<String>> supercl = PrologInterface.
                    executeQuery("owl_subclass_of(" + PrologInterface.addSingleQuotes(val) + ", Super)");
            
            for(String sup : supercl.get("Super")) {
                if(knowrobToCPL.containsKey(PrologInterface.valueFromIRI(sup))) {
                    return knowrobToCPL.getString(PrologInterface.valueFromIRI(sup));
                }
            }
            return lispify(val);
        }
    }
    
    /**
     * 'Lispify' a string: convert from Java CamelCaseSyntax into
     *  hyphenated-lower-case-syntax.
     *  
     * @param pl String to be lispified
     * @return Resulting string in lowercase, hyphenated style
     */
    private String lispify(String pl) {
        
        // extract value from IRI
        String val = PrologInterface.valueFromIRI(PrologInterface.removeSingleQuotes(pl));
        val = CaseFormat.UPPER_CAMEL.to(CaseFormat.LOWER_HYPHEN, val);
        val = val.replaceAll("--", "-");
        
        return val;
    }
    
    
    
    /**
     * Read JSON-formatted configuration file to initialize the mapping between
     * KnowRob classes and CPL identifiers
     * 
     * @param configFile
     * @throws java.io.IOException
     */

    public JSONObject readCplMapping(String configFile)
            throws java.io.IOException {

        byte[] buffer = new byte[(int) new File(configFile).length()];
        BufferedInputStream f = null;
        try {
            f = new BufferedInputStream(new FileInputStream(configFile));
            f.read(buffer);
        } finally {
            if (f != null)
                try {
                    f.close();
                } catch (IOException ignored) {
                }
        }

        return (JSONObject) JSONSerializer.toJSON(new String(buffer));
    }

    
    /**
     * Create unique identifier from a class description
     * 
     * @param cl
     *            Class description
     * @return Identifier: class description plus numeric ID
     */
    private String instanceFromClass(String cl) {
        return (cl + (inst_counter++)).toLowerCase();
    }

    
    /**
     * Main function for testing purposes
     * 
     * @param args
     */
    public static void main(String[] args) {
        
        try {
            
            PrologInterface.initJPLProlog("knowrob_actions");
            PlanExporter pl = new PlanExporter();
            String plan = pl.exportPlanToCPL("http://www.roboearth.org/kb/serve_drink.owl#ServeADrink");
            System.out.println(plan);
            
        } catch (IOException e) {
            e.printStackTrace();
        }
        
    }
    
}
