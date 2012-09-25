package edu.tum.cs.ias.knowrob.vis.applets;

import java.awt.Color;
import java.awt.Cursor;
import java.awt.event.KeyEvent;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.awt.event.MouseMotionListener;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Vector;

import javax.vecmath.Vector2f;

import controlP5.ControlEvent;
import controlP5.ControlFont;
import controlP5.ControlP5;
import controlP5.Controller;
import controlP5.MultiList;
import controlP5.MultiListButton;
import controlP5.Textfield;
import edu.tum.cs.ias.knowrob.owl.OWLThing;
import edu.tum.cs.ias.knowrob.prolog.PrologInterface;
import edu.tum.cs.ias.knowrob.vis.actions.ActionTransition;
import edu.tum.cs.ias.knowrob.vis.actions.ActionTransitions;
import edu.tum.cs.ias.knowrob.vis.themes.GreyTheme;


import processing.core.PApplet;
import processing.core.PFont;


/**
 * GUI for selecting an OWL class using free-text search or by clicking through the hierarchy
 * 
 * @author Moritz Tenorth, tenorth@cs.tum.edu
 *
 */
public class OwlClassSelectorApplet  extends PApplet implements MouseListener, MouseMotionListener {

	private static final long serialVersionUID = 7695328948788620463L;
	

	/**
	 * ControlP5 GUI library instance
	 */
	public ControlP5 controlP5;

	/**
	 * GUI element holding the classes that can be selected
	 */
	MultiList class_listbox ;
	
	/**
	 * Position where mouse dragging started
	 */
	private Vector2f draggingStart;

	/**
	 * Normal cursor (arrow)
	 */
	private static final Cursor normalCursor = new Cursor(Cursor.DEFAULT_CURSOR);
	
	/**
	 * Move cursor
	 */
	private static final Cursor moveCursor = new Cursor(Cursor.MOVE_CURSOR);

	
	
	/**
	 * Hierarchical list of OWL classes
	 */
	private ArrayList<OWLClass> owl_classes;
	
	/**
	 * Mapping from a numeric ID to an OWLClass (needed to assign click events)
	 */
	private Map<Float, OWLClass> id2class;
	
	/**
	 * Buffer for the result of searching for a class using the text field
	 */
	private OWLClass searchResult = null;

	/**
	 * Callback to be notified once class has been selected
	 */
	private IClassSelectionCallback cb;


	private Textfield search;
	
	
	/**
	 * Initialize the applet elements
	 */
	@Override
	public void setup()
	{
		size(800, 600);

		if (this.frame != null)
		{
			this.frame.setTitle("OWL class selector");
			this.frame.setBackground(new Color(10, 10, 10));
		}

		frameRate(10);
		
		id2class = new HashMap<Float, OWLClass>();
		owl_classes = new ArrayList<OWLClass>();
		
		
		// TODO make base class configurable
		readSubClassesFromOWL("knowrob:'PurposefulAction'", null);
		
		
		initControlP5();
	}


	/** 
	 * Draw the applet elements
	 */
	@Override
	public void draw() {

		background(50);
		controlP5.draw();
	}



	
	// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 
	// 
	//  Searching for OWL classes
	// 
	
	
	/**
	 * Greedy search in the OWL class structure: return the first match and highlight 
	 * it in the GUI
	 * 
	 * @param stringValue
	 * @param owl_classes
	 * @return
	 */
	private OWLClass searchOWLClass(String stringValue, List<OWLClass> owl_classes) {
		
		for(OWLClass a : owl_classes) {
			
			if(a.iri.toLowerCase().contains(stringValue.toLowerCase())) {
				
				showSearchResult(a);
				return a;
				
			} else if(a.label.toLowerCase().contains(stringValue.toLowerCase())) {

				showSearchResult(a);
				class_listbox.update();
				
				return a;
				
			} else if(a.subclasses.size()>0){
				
				OWLClass found = searchOWLClass(stringValue, a.subclasses);
				
				if(found!=null) {
					return found;
				}
			}
		}
		return null;
	}



	private void showSearchResult(OWLClass a) {
		
		// reset highlight
		if(searchResult!=null)
			searchResult.getListButton().setColorBackground(80);
		
		// try to open the right tab
		OWLClass tmp = a;
		while(tmp.getParent()!=null) {
			tmp.getParent().getListButton().open();
			tmp = tmp.getParent();
		}
		
		
		// highlight the result
		a.getListButton().setColorBackground(color(180));
		searchResult = a;
		class_listbox.update();
	}

	

	
	// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 
	// 
	//  Event handling
	// 
	

	public void controlEvent(ControlEvent ev) {
		
		// submit selection with ENTER if selection has been made, search otherwise
		if(ev.getController().getName().equals("search")) {

			if(searchResult!=null) {
				cb.owlClassSelected(searchResult.getIRI());
				this.frame.setVisible(false);
			} else {
				searchOWLClass(ev.getStringValue(), owl_classes);
			}
			return;
		}
		
		if(ev.getController().getName().equals("class list")) {
			
			if(this.cb!=null) {
				cb.owlClassSelected(id2class.get(Float.valueOf(ev.getValue())).getIRI());
				this.frame.setVisible(false);
				
			} else {
				System.out.println("Selected class " + id2class.get(Float.valueOf(ev.getValue())).getIRI());
			}
		}
	}
	
	public void keyPressed(KeyEvent e) {
		
		// search in class structure with TAB
		if(e.getKeyCode() == KeyEvent.VK_TAB) {
			searchOWLClass(((Textfield) search).getText(), owl_classes);
			return;
		} else {
			controlP5.keyHandler.keyEvent(e, controlP5.controlWindow, true);
		}
		
	}
	
	@Override
	public void mouseDragged(MouseEvent e) {

		if (draggingStart != null) {

			this.class_listbox.updateLocation(e.getX() - draggingStart.x,
								  			  e.getY() - draggingStart.y);

			draggingStart.x = e.getX();
			draggingStart.y = e.getY();
		}
		
		// only forward left-clicks to ControlP5 
		// (no class selection by right click/dragging)
		if (e.getButton() == MouseEvent.BUTTON1) {
			controlP5.controlWindow.mouseEvent(e);
		}
	}

	@Override
	public void mousePressed(MouseEvent e) {

		if (e.getButton() == MouseEvent.BUTTON3) {

			draggingStart = new Vector2f(e.getX(),e.getY());
			setCursor(moveCursor);

		} else {
			setCursor(normalCursor);
		}
		
		// only forward left-clicks to ControlP5 
		// (no class selection by right click/dragging)
		if (e.getButton() == MouseEvent.BUTTON1) {
			controlP5.controlWindow.mouseEvent(e);
		}
	}

	@Override
	public void mouseReleased(MouseEvent e) {
		setCursor(normalCursor);
		draggingStart = null;
		
		// only forward left-clicks to ControlP5 
		// (no class selection by right click/dragging)
		if (e.getButton() == MouseEvent.BUTTON1) {
			controlP5.controlWindow.mouseEvent(e);
		}
	}

	public void mouseClicked(MouseEvent e) {
		
		// only forward left-clicks to ControlP5 
		// (no class selection by right click/dragging)
		if (e.getButton() == MouseEvent.BUTTON1) {
			controlP5.controlWindow.mouseEvent(e);
		}
	}

	public void setClassSelectedCallback(IClassSelectionCallback cb) {
		this.cb = cb;		
	}


	
	
	// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 
	// 
	//  Initialize GUI elements
	// 

	/** 
	 * Initialize the GUI elements, including reading the available classes
	 */
	private void initControlP5() {

		controlP5 = new ControlP5(this);
		GreyTheme.applyStyle(controlP5);
		
		search = controlP5.addTextfield("search", 20, 20, 200, 20).setAutoClear(false).setFocus(true);
		class_listbox = GreyTheme.applyStyle(controlP5.addMultiList("class list", 20, 60, 80, 17));

		float textwidth = textWidth("CheckingWhetherConditionObtains");
		class_listbox.setWidth((int)textwidth + 10);
		
		createListButtons(owl_classes, class_listbox, 0, 0);
	}
	
	
	/**
	 * Recursively create the {@link MultiListButton}s for an {@link OWLClass} hierarchy
	 * 
	 * @param owl_classes {@link OWLClass} datastructure
	 * @param parent {@link Controller}, either a {@link MultiList} or a {@link MultiListButton}
	 * @param start_idx index for creating the continuously numbered buttons
	 * @return index of the last button created
	 */
	private int createListButtons(List<OWLClass> owl_classes, Controller<?> parent, int start_idx, int level) {

		int idx = start_idx;

		for(OWLClass act : owl_classes) {

			MultiListButton b = null;
			if (parent instanceof MultiList) {
				
				b = ((MultiList)parent).add(idx + "_" + act.getIRI(), idx++);
				configureButton(b, level, act);

			} else if (parent instanceof MultiListButton) {
				
				b = ((MultiListButton)parent).add(idx + "_" + act.getIRI(), idx++);
				configureButton(b, level, act);
			} 

			if(act.getSubclasses().size()>0)
				idx = createListButtons(act.subclasses, b, idx, level+1);
		}
		return idx;
	}


	
	/**
	 * Internal helper: set some properties of the create MultiListButton
	 * 
	 * @param b MultiListButton to be set up
	 * @param level Level in the MultiList hierarchy
	 * @param act OWL class associated with this button
	 */
	private void configureButton(MultiListButton b, int level, OWLClass act) {
		
		GreyTheme.applyStyle(b);
		b.setCaptionLabel(act.getLabel());
		
		if(level>=3)
			b.getCaptionLabel().setColor(color(10));
		
		act.setListButton(b);
		act.setColorBackground(color(80 + 30 * level));
		
		id2class.put(b.getValue(), act);
	}

	
	
	
	// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 
	// 
	//  OWL class datastructure
	// 



	/**
	 * Recursively read all sub-classes of an OWL class into the owl_classes datastructure.
	 * 
	 * @param cls String with the OWL class name
	 * @param sup Super class of the current class (if null, the created class will be added 
	 *            to the owl_classes member variable.
	 */
	public void readSubClassesFromOWL(String cls, OWLClass sup) {
		
		HashMap<String, Vector<String>> subclasses = PrologInterface.executeQuery(
				"owl_direct_subclass_of(Sub, " + cls + "), " +
				"(rdf_has(Sub, rdfs:label, literal(type(xsd:string, Label))) -> true; Label='', true)");

		if(subclasses!=null && subclasses.get("Sub") != null && subclasses.get("Label") != null) {
			for(int i=0;i<subclasses.get("Sub").size();i++) {

				String iri = subclasses.get("Sub").get(i);
				String label = subclasses.get("Label").get(i);


				OWLClass sub;
				if(label.equals("''"))
					sub = new OWLClass(PrologInterface.removeSingleQuotes(iri), OWLThing.getShortNameOfIRI(iri));
				else
					sub = new OWLClass(PrologInterface.removeSingleQuotes(iri), PrologInterface.removeSingleQuotes(label));

				// either add to the specified super-class or to the general list of top-level classes
				if(sup!=null) {
					sup.addSubclass(sub);
				} else {
					owl_classes.add(sub);
				}

				// iterate deeper
				readSubClassesFromOWL(iri, sub);
			}
		}
	}
	
	

	/**
	 * Wrapper class around a hierarchical OWL class structure
	 *  
	 * @author Moritz Tenorth, tenorth@cs.tum.edu
	 *
	 */
	public class OWLClass implements Comparable<OWLClass> {
		
		String iri;
		String label;
		List<OWLClass> subclasses;
		
		MultiListButton button;
		OWLClass parent;
		int bgcolor;
		
		public OWLClass(String iri, String label) {
			
			this.iri = iri;
			this.label = label;
			this.subclasses = new ArrayList<OWLClass>();
		}

		public String getIRI() {
			return iri;
		}

		public void setIri(String iri) {
			this.iri = iri;
		}

		public String getLabel() {
			return label;
		}

		public void setLabel(String label) {
			this.label = label;
		}
		
		public List<OWLClass> getSubclasses() {
			return subclasses;
		}
		
		public void addSubclass(OWLClass sub) {

			subclasses.add(sub);
			sub.setParent(this);
		}
		
		public void removeSubclass(OWLClass sub) {
			subclasses.remove(sub);
		}
		
		public void setListButton(MultiListButton b) {
			button = b;
		}
		
		public MultiListButton getListButton() {
			return button;
		}
		
		public void setParent(OWLClass p) {
			parent = p;
		}
		
		public OWLClass getParent() {
			return parent;
		}
		
		public void setColorBackground(int color) {
			if(button!=null)
				button.setColorBackground(color);
			
			bgcolor = color;
		}
		
		public int getColorBackground() {
			return bgcolor;
		}

		@Override
		public int compareTo(OWLClass o) {
			return this.iri.compareTo(o.getIRI());
		}
		
	}

	public static void main(String args[]) {
		PApplet.main(new String[] { "edu.tum.cs.ias.knowrob.vis.applets.OwlClassSelectorApplet" });
	}



}

